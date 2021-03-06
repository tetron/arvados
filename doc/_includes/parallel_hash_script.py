#!/usr/bin/env python

import hashlib
import arvados

# Jobs consist of one of more tasks.  A task is a single invocation of
# a crunch script.

# Get the current task
this_task = arvados.current_task()

# Tasks have a sequence number for ordering.  All tasks
# with the current sequence number must finish successfully
# before tasks in the next sequence are started. 
# The first task has sequence number 0
if this_task['sequence'] == 0:
    # Get the "input" field from "script_parameters" on the task object
    job_input = arvados.current_job()['script_parameters']['input']

    # Create a collection reader to read the input
    cr = arvados.CollectionReader(job_input)

    # Loop over each stream in the collection (a stream is a subset of
    # files that logically represents a directory
    for s in cr.all_streams():

        # Loop over each file in the stream
        for f in s.all_files():

            # Synthesize a manifest for just this file
            task_input = f.as_manifest()

            # Set attributes for a new task:
            # 'job_uuid' the job that this task is part of
            # 'created_by_job_task_uuid' this task that is creating the new task
            # 'sequence' the sequence number of the new task
            # 'parameters' the parameters to be passed to the new task
            new_task_attrs = {
                'job_uuid': arvados.current_job()['uuid'],
                'created_by_job_task_uuid': arvados.current_task()['uuid'],
                'sequence': 1,
                'parameters': {
                    'input':task_input
                    }
                }

            # Ask the Arvados API server to create a new task, running the same
            # script as the parent task specified in 'created_by_job_task_uuid'
            arvados.api().job_tasks().create(body=new_task_attrs).execute()

    # Now tell the Arvados API server that this task executed successfully,
    # even though it doesn't have any output.
    this_task.set_output(None)
else:
    # The task sequence was not 0, so it must be a parallel worker task
    # created by the first task

    # Instead of getting "input" from the "script_parameters" field of
    # the job object, we get it from the "parameters" field of the
    # task object
    this_task_input = this_task['parameters']['input']

    collection = arvados.CollectionReader(this_task_input)

    out = arvados.CollectionWriter()
    out.set_current_file_name("md5sum.txt")

    # There should only be one file in the collection, so get the
    # first one.  collection.all_files() returns an iterator so we
    # need to make it into a list for indexed access.
    input_file = list(collection.all_files())[0]

    # Everything after this is the same as the first tutorial.
    digestor = hashlib.new('md5')

    while True:
        buf = input_file.read(2**20)
        if len(buf) == 0:
            break
        digestor.update(buf)

    hexdigest = digestor.hexdigest()
    file_name = input_file.name()
    if input_file.stream_name() != '.':
        file_name = os.join(input_file.stream_name(), file_name)
    out.write("%s %s\n" % (hexdigest, file_name))
    output_id = out.finish()
    this_task.set_output(output_id)

# Done!
