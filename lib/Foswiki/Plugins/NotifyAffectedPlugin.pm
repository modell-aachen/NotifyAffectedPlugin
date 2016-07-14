# See bottom of file for default license and copyright information

package Foswiki::Plugins::NotifyAffectedPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '1.0';
our $RELEASE = '1.0';

our $SHORTDESCRIPTION = 'Notify responsible people, when a topic is affected by topic changes.';

our $NO_PREFS_IN_TOPIC = 1;

# Each run we collect changed topics here and send them when finished rendering the page
our $changedTopics = undef;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.3 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub afterSaveHandler {
    my ($text, $topic, $web, $error, $meta) = @_;

    notifyTopicChange($web, $topic);
}

sub afterRenameHandler {
    my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    # TODO: Web rename

    notifyTopicChange($oldWeb, $oldTopic) if $oldTopic;
    notifyTopicChange($newWeb, $newTopic) if $newTopic;
}

# Trigger the grinder for a topic
# Parameters:
#    * web,topic: the changed topic
sub notifyTopicChange {
    my ( $web, $topic ) = @_;

    my $webtopic = "$web.$topic";

    my $condition = $Foswiki::cfg{Plugins}{NotifyAffectedPlugin}{Condition};
    if(defined $condition && $condition ne '') {
        $condition =~ s#\$web#$web#g;
        $condition =~ s#\$topic#$topic#g;
        my $result = Foswiki::Func::expandCommonVariables($condition, $topic, $web);

        return unless Foswiki::Func::isTrue($result);
    }

    $changedTopics = {} unless $changedTopics;
    $changedTopics->{"$web.$topic"} = 1;
}

sub completePageHandler {
    return unless $changedTopics;

    foreach my $changedTopic ( keys %$changedTopics ) {
        Foswiki::Plugins::TaskDaemonPlugin::send($changedTopic, 'topic_changed', 'NotifyAffectedPlugin', 0);
    }

    $changedTopics = undef;
}
1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
