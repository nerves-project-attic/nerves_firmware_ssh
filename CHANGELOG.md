# Changelog

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
