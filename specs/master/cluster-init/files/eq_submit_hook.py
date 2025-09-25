# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
"""
Note - the pbs module isn't very pythonic, so you'll see things like
    value = job.Resource_List["attribute"] or 100
instead of
    value = job.Resource_List.get("attribute", 100)
That is because is a metaclass, not a dict.

Also, place and select objects use repr() to convert to a parseable string, but
so you'll see guards against repr(None) (combined with the above) and 

NOTE: Config json is different when used on-prem compared to CycleCloud 
      This python script is for both the submit and periodic hook

Quick start:
        
    /opt/pbs/bin/qmgr -c "list hook eq_submit_hook" >& /dev/null || /opt/pbs/bin/qmgr -c "create hook eq_submit_hook" 
    /opt/pbs/bin/qmgr -c "import hook eq_submit_hook application/x-python default eq_submit_hook.py"       # Same python script
    /opt/pbs/bin/qmgr -c "import hook eq_submit_hook application/x-config default eq_submit_hook.json"     # _cc.json for CycleCloud
    /opt/pbs/bin/qmgr -c "set hook eq_submit_hook event = queuejob"

    /opt/pbs/bin/qmgr -c "list hook eq_periodic_hook" >& /dev/null || /opt/pbs/bin/qmgr -c "create hook eq_periodic_hook"
    /opt/pbs/bin/qmgr -c "import hook eq_periodic_hook application/x-python default eq_submit_hook.py"     # Same python script
    /opt/pbs/bin/qmgr -c "import hook eq_periodic_hook application/x-config default eq_submit_hook.json"   # _cc.json for CycleCloud
    /opt/pbs/bin/qmgr -c "set hook eq_periodic_hook event = periodic"
    /opt/pbs/bin/qmgr -c "set hook eq_periodic_hook freq = 15"

Queue setup
    qmgr -c "set queue <queue_name> resources_default.slot_type = <queue_name>"
    qmgr -c "set queue <queue_name> default_chunk.slot_type = <queue_name>"
    
Debugging:
    cp -v eq_submit_hook.py /var/spool/pbs/server_priv/hooks/eq_submit_hook.PY
    cp -v eq_submit_hook.py /var/spool/pbs/server_priv/hooks/eq_periodic_hook.PY
    tail -f /var/spool/pbs/server_logs/<date> /opt/cycle/pbspro/autoscale.log
    
    ... then submit test jobs

See PBS Professional Programmers Guide for detailed information.
"""
import io
import json
import os
import subprocess
import traceback
import sys

try:
    import pbs
except ImportError:
    import mockpbs as pbs

def debug(msg):
    pbs.logmsg(pbs.EVENT_DEBUG, "cycle_periodic_hook_place - %s" % msg)


def error(msg):
    pbs.logmsg(pbs.EVENT_ERROR, "cycle_periodic_hook_place - %s" % msg)


def hold_on_submit(hook_config, event):
    """
    Hold every legacy syntax job so that we can process it properly in the periodic hook.
    """
    job = event.job
    
    # Submit_arguments is not available at this point
    j_select = job.Resource_List["select"]
    if j_select:
        j_sel_str = str(j_select)
        debug("Select is %s" % j_sel_str)
        m_pos = j_sel_str.find("mem=")
        if m_pos < 0:
            debug("job %s has select syntax and no memory requirements - not held/modified" % job.id)
            return
        if j_sel_str.lower()[m_pos:] == j_sel_str[m_pos:]:
            debug("job %s has select syntax and lower case memory spec - not held/modified" % job.id)
            return

    debug(
        (
            "holding job %s with hold_type 'so' because it does not use -l select syntax."
            + " or because memory requirements need translation due to uppercase units being used."
            + " It will be updated and released shortly."
        )
        % job.id
    )
    job.Hold_Types = pbs.hold_types("so")
    event.accept()
    return


# Vendored in from pbscc.py
def parse_place(place):
    """
    arrangement is one of free | pack | scatter | vscatter
    sharing is one of excl | shared | exclhost
    grouping can have only one instance of group=resource
    """
    placement = {}

    if not place:
        return placement

    toks = place.split(":")

    for tok in toks:
        if tok in ["free", "pack", "scatter", "vscatter"]:
            placement["arrangement"] = tok
        elif tok in ["excl", "shared", "exclhost"]:
            placement["sharing"] = tok
        elif tok.startswith("group="):
            placement["grouping"] = tok

    return placement


def format_place(place_dict):
    parts = []
    for key in ["arrangement", "sharing", "grouping"]:
        if place_dict.get(key):
            parts.append(place_dict[key])
    return ":".join(parts)


QSELECT_EXE = os.path.join(pbs.pbs_conf["PBS_EXEC"], "bin", "qselect")
QSTAT_EXE = os.path.join(pbs.pbs_conf["PBS_EXEC"], "bin", "qstat")
QALTER_EXE = os.path.join(pbs.pbs_conf["PBS_EXEC"], "bin", "qalter")
QRLS_EXE = os.path.join(pbs.pbs_conf["PBS_EXEC"], "bin", "qrls")
QHOLD_EXE = os.path.join(pbs.pbs_conf["PBS_EXEC"], "bin", "qhold")


def unset_hold_so(job_id, job):
    if "depend" in job and not job["depend"].startswith("before"):
        run_cmd([QRLS_EXE, "-h", "o", job_id])
    else:
        run_cmd([QRLS_EXE, "-h", "so", job_id])


def periodic_release_hook(hook_config, e):
    held_jobs_per_iteration = int(hook_config.get("held_jobs_per_iteration", 25))

    # Defined paths to PBS commands

    # Get the jobs in an "so" hold state
    qselect_cmd = [QSELECT_EXE, "-h", "so"]
    stdout = run_cmd(qselect_cmd)
    jobs = stdout.split()
    debug("Jobs: %s" % jobs)

    # Get the job information
    if not jobs:
        debug("No jobs to evaluate")
        e.accept()
        return

    # Get Queue defaults information
    queue_cmd = [QSTAT_EXE, "-Qf", "-F", "json"]
    stdout = run_cmd(queue_cmd)
    qstat_Qf_json = json.loads(stdout)

    # Get job information
    job_cmd = [QSTAT_EXE, "-f", "-F", "json"] + jobs[:held_jobs_per_iteration]
    stdout = run_cmd(job_cmd)
    qstat_json = json.loads(stdout)
    jobs = qstat_json["Jobs"]

    for job_id, job in jobs.items():
        # Reevaluate each held job
        debug("Key: %s\nValue: %s" % (job_id, job))
        if str(job["Resource_List"].get("skipcycle")).lower() == "true":
            debug("skipcycle is true for job %s, skipping" % job_id)
            unset_hold_so(job_id, job)
            continue

        j_queue = job["queue"]
        j_select = job["Resource_List"].get("select") or "1:ncpus=1"
        j_submit_args = job.get("Submit_arguments") or "-l nodes=1"
        j_legacy = "select" not in j_submit_args

        # Check the groupid placement
        mj_place = job["Resource_List"].get("place")

        mj_place_dict = parse_place(mj_place)

        # Assign default placement from queue. If none, assign group=group_id
        if j_queue in qstat_Qf_json["Queue"]:
            if "resources_default" in qstat_Qf_json["Queue"][j_queue]:
                if "place" in qstat_Qf_json["Queue"][j_queue]["resources_default"]:
                    # only update arrangement (scatter/pack/vscatter/free) and sharing (excl/shared) if _neither_ is specified
                    # Do not override grouping if user specified it.
                    # -l place=scatter is automatically added to -l nodes jobs, so we will remove it here and if it is not
                    # overridden by the queue defaults, we will bring it back
                    if j_legacy:
                        debug("no select in Submit_arguments %s" % j_submit_args)
                        mj_place_dict = {}

                    default_place = qstat_Qf_json["Queue"][j_queue]["resources_default"]["place"]
                    default_place_dict = parse_place(default_place)

                    # if the user specifies either arrangement or sharing, ignore them as far as defaults are concerned
                    specified_at_least_one_of_arrangement_or_sharing = (
                        len(set(mj_place_dict.keys()) - set(["grouping"])) > 0
                    )
                    if specified_at_least_one_of_arrangement_or_sharing:
                        default_place_dict.pop("sharing", "")
                        default_place_dict.pop("arrangement", "")

                    # update if not exist from defaults
                    for k, v in default_place_dict.items():
                        mj_place_dict[k] = mj_place_dict.get(k, v)

                    # the job is a -l nodes job and the queue didn't specify arrangement or sharing
                    if (
                        j_legacy
                        and mj_place_dict.get("arrangement") is None
                        and mj_place_dict.get("sharing") is None
                    ):
                        mj_place_dict["arrangement"] = "scatter"

                    mj_place = format_place(mj_place_dict)
                    debug("mj_place is %s" % mj_place)

        mj_place = format_place(mj_place_dict)

        # Double checking group=group_id setting:
        placement_grouping = None
        for expr in mj_place.split(":"):
            placement_grouping = None
            if "=" in expr:
                placekey, value = [x.lower().strip() for x in expr.split("=", 2)]
                if placekey == "group":
                    placement_grouping = value

        if placement_grouping is None:
            debug("The user didn't specify place=group, setting group=group_id")
            debug(
                "%s - The user didn't specify place=group, setting group=group_id"
                % mj_place
            )
            placement_grouping = "group_id"
            prefix = ":" if mj_place else ""
            mj_place = mj_place + prefix + "group=group_id"
            debug("after update %s" % mj_place)
        
        n_select = j_select
        if "mem=" in j_select:
            # Get the memory string from the PBS resources - then try find a lowecase match
            # If found, replace that part with the lower case job attribute
            # the :-1 slice is because we can have both G and GB 
            j_mem = job["Resource_List"].get("mem")
            m_pos = j_select.lower().find(j_mem[:-1]) 
            if m_pos >= 0:
                l_mem = len(j_mem)
                n_select = j_select[0:m_pos] + j_select[m_pos:].lower()

        if mj_place != job["Resource_List"].get("place") or n_select != j_select:
            # Qalter the job
            qalter_cmd = [QALTER_EXE]
            debug("New place statement: %s" % mj_place)
            debug("select before qalter %s" % j_select)
            debug("select after qalter %s" % n_select)
            debug("before qalter %s" % mj_place)
            qalter_cmd.append("-lselect=%s" % n_select)
            qalter_cmd.append("-lplace=%s" % mj_place)
            debug("qalter the job")
            qalter_cmd.append(job_id)
            debug("full cmd %s" % qalter_cmd)
            stdout = run_cmd(qalter_cmd)
            debug("stdout %s" % stdout)

        debug("Release the hold on job %s" % job_id)
        unset_hold_so(job_id, job)

    e.accept()


def run_cmd(cmd):
    debug("Cmd: %s" % cmd)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if hasattr(stdout, "decode"):
        stdout = stdout.decode()
        stderr = stderr.decode()
    if proc.returncode != 0:
        msg = 'cmd failed!\n\tstdout="%s"\n\tstderr="%s"' % (stdout, stderr)
        error(msg)
        sys.exit(proc.returncode)

    return stdout


def main():
    try:
        hook_config = {}
        if pbs.hook_config_filename:
            with open(pbs.hook_config_filename) as fr:
                hook_config.update(json.load(fr))

        e = pbs.event()
        if e.type == pbs.QUEUEJOB:
            j = e.job
            hold_on_submit(hook_config, e)
        elif e.type == pbs.PERIODIC:
            periodic_release_hook(hook_config, e)
        else:
            pbs.logmsg(pbs.EVENT_ERROR, "Unknown event type %s" % e.type)
    except SystemExit as e:
        debug("Exited with SystemExit - %s" % e)
        raise
    except:
        error(traceback.format_exc())
        raise


# another non-pythonic thing - this can't be behind a __name__ == '__main__',
# as the hook code has to be executable at the load module step.
if not os.getenv("_UNITTEST_", ""):
    main()
