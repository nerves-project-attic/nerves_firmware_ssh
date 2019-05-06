# Changelog

## v0.4.3

* Improvements
  * Minor project cleanup. No functional changes.

## v0.4.2

* Improvements
  * Validate authorized ssh keys to avoid accidents that prevent firmware
    updates
  * Print out firmware metadata when uploading

## v0.4.1

* Improvements
  * Updated upload.sh script to support Elixir 1.8 changes to output paths

## v0.4.0

Support for `mix firmware.push` has been removed. We're all very sorry for this,
but it appears to be unfixable. It was implemented using Erlang's built-in ssh
client which doesn't know about things like the `ssh-agent` or the `.ssh/config`
and can't ask for passwords. It also isn't possible to call the system's `ssh`
since Erlang runs `setsid` on child processes so they don't have a tty.

The workaround is to run `mix firmware.gen.script` and then run `./upload.sh`.

* Bug fixes
  * Fix exit code parsing from fwup so that errors can be propogated over ssh
  * Disabled the Erlang shell and remote command execution on the firmware
    update port

## v0.3.3

* Bug fixes
  * Fixed exit code returned over ssh so that uploads could be scripted and
    checked that they ran successfully.

## v0.3.2

* Bug fixes
  * Removed workaround for ERL-469 that prevented use of ssh-agent. This
    requires Erlang >= 20.2.1 running on the target. That's been out for a while
    in the official systems, so hopefully people have upgraded.

## v0.3.1

* Improvements
  * Try guessing the link local interface when multiple exist on OSX. Guessing
    the last one seems to work.

## v0.3.0

* Improvements
  * If using the upload.sh script, there's no need to copy it anymore. Just
    run `mix firmware.gen.script` to get a copy.

* Bug fixes
  * Fix race condition that prevented firmware update errors from being
    returned. This requires fwup v0.17.0 to work which is included in the
    latest nerves_system_br release and official systems.
  * Fixed a couple errors on OSX with the upload script.

## v0.2.2

* Improvements
  * Remove my name from the throwaway ssh key
  * Documentation updates throughout
  * Some upload.sh fixes to workaround issues discovered with ssh

## v0.2.1

* Bug fixes
  * Fix Elixir 1.5 warnings
  * Improve docs

## v0.2.0

* Bug fixes
  * Force publickey mode to avoid password prompt that will never work
  * Improve docs

## v0.1.0

* Initial release
