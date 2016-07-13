use strict;
use warnings;

use Foswiki::Contrib::MailTemplatesContrib;
use Foswiki::Plugins::SolrPlugin;
use Foswiki::Plugins::SolrPlugin::Search;

{
    handle_message => sub {
        my ($host, $type, $hdl, $run_engine, $json) = @_;

        eval { $run_engine->(); };

        return {};
    },
    engine_part => sub {
        my ($session, $type, $data, $caches) = @_;

        my $searcher = Foswiki::Plugins::SolrPlugin::getSearcher($session);
        my $affectedTopics = $searcher->handleSOLRSEARCH({
            _DEFAULT => "outgoing:$data OR outgoing_AttachmentTopic_lst:$data OR parent:$data",
            format=>"\$webtopic",
            fields=>"webtopic",
            separator=>","
        });

        my ($dependencyWeb, $dependencyTopic) = Foswiki::Func::normalizeWebTopicName(undef, $data);

        my ($meta, undef) = Foswiki::Func::readTopic($dependencyWeb, $dependencyTopic);
        my $dependencySetting = $meta->get('PREFERENCE', 'NOTIFY_AFFECTED');
        if($dependencySetting) {
            $dependencySetting = $dependencySetting->{value};
        } else {
            $dependencySetting = Foswiki::Func::getPreferencesValue('NOTIFY_AFFECTED', $dependencyWeb, $dependencyTopic);
        }

        # Arguably this should be configurable on a web/topic level, maybe even
        # as TML.
        # If you call your field '0' I won't like you anymore.
        my $field = $Foswiki::cfg{Plugins}{NotifyAffectedPlugin}{Formfield} || 'Responsible';

        my $mails = {};

        foreach my $affectedTopic ( split(",", $affectedTopics ) ) {
            my($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $affectedTopic);

            my ($affectedMeta, undef) = Foswiki::Func::readTopic($web, $topic);

            my $responsible = $affectedMeta->get('FIELD', $field);
            next unless $responsible;
            $responsible = $responsible->{value};
            next unless $responsible;

            my $affectedSetting = $affectedMeta->get('PREFERENCE', 'NOTIFY_ABOUT_DEPENDENCIES');
            if($affectedSetting) {
                $affectedSetting = $affectedSetting->{value};
            } else {
                $affectedSetting = Foswiki::Func::getPreferencesValue('NOTIFY_ABOUT_DEPENDENCIES', $web, $topic);
            }

            next if ((defined $affectedSetting) && (not Foswiki::Func::isTrue($affectedSetting)));
            next if ((not defined $affectedSetting) && (not Foswiki::Func::isTrue($dependencySetting)));

            # We need to separate the list of topics somehow. Let's hope noone uses burgers in their topic names.
            if($mails->{$responsible}) {
                $mails->{$responsible} .= "\x{2630}";
            } else {
                $mails->{$responsible} = "";
            }
            $mails->{$responsible} .= "$web/$topic";
        }

        $data =~ s#\.#/#g; # We use slashes all the way, because it makes generating links a bit easier.
        foreach my $responsible ( keys %$mails ) {
            Foswiki::Contrib::MailTemplatesContrib::sendMail('affectedmail', { IncludeCurrentUser => 1 }, {AffectedTopicResponsible => $responsible, AffectedWebTopicList => $mails->{$responsible}, AffectedDependency => $data}, 1);
        }
    },
};
