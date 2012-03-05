## Using Old Boson

Any version before 1.0 is considered the old boson. Although I will accept bug
fixes for it (branched from
[old_boson](http://github.com/cldwalker/boson/tree/old_boson)), I will *not*
accept any new features. Since the new boson supports almost all of [boson's
origin functionality](http://tagaholic.me/blog.html#gem:name=boson) via plugins,
there is little reason to hang onto this version.

## Using New Boson

To enjoy the same experience you've had with the old boson, you'll need to
also install boson-more and create a ~/.bosonrc:

    $ gem install boson boson-more
    $ echo "require 'boson/more'" > ~/.bosonrc

Your old boson config and libraries should just work. Please file issues with
your libraries or any upgrade issues at
[boson-more](http://github.com/cldwalker/boson-more).

If you've written custom plugins for the old Boson, you most likely have to
upgrade to the new API.
