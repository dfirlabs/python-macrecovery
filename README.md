# python-macrecovery

This is a compilation of scripts to be run on a MacOS (tested only on intel),
enviromnent, to help a DF investigator run [GiftStick](https://github.com/google/GiftStick)
in a Mac Recovery terminal, that usually doesn't offer a dedicated Python environment

# Tools

## minithon.sh

Running `minithon.sh` in a Mac termian (with the SDK installed) will generate
a tarball with everything needed to extract in a Mac recovery environment and
get your favorite Python script running.

The easy method is to just run `bash minithon.sh`, wait for `minithon.tgz` to
be created, and upload this to a place that will be accesible later on.

## recovery_run.sh

This script will pull the previously generated tarball, extract it in `/opt`
(which is one of the rare places that is writeable in recovery mode), and then
setup everything properly so that you can run [GiftStick](https://github.com/google/GiftStick)
acquisition code from your recovery terminal. Hence uploading a logical copy
of the file system to GCS.
