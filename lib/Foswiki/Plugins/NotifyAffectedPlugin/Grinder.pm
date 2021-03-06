use strict;
use warnings;

use JSON;

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

        $data = decode_json($data);

        my $webtopic = $data->{webtopic};
        $webtopic =~ s#/#.#g; # we need dots for searching

        my $lastProcessor = $data->{lastProcessor};

        my $searcher = Foswiki::Plugins::SolrPlugin::getSearcher($session);
        my $affectedTopics = $searcher->handleSOLRSEARCH({
            _DEFAULT => "outgoingWiki_lst:$webtopic OR outgoing_AttachmentTopic_lst:$webtopic",
            format=>"\$webtopic",
            fields=>"webtopic",
            separator=>","
        });

        my ($dependencyWeb, $dependencyTopic) = Foswiki::Func::normalizeWebTopicName(undef, $data->{webtopic});

        my ($meta, undef) = Foswiki::Func::readTopic($dependencyWeb, $dependencyTopic);
        my $dependencySetting = $meta->getPreference('NOTIFY_AFFECTED');
        unless(defined $dependencySetting) {
            $dependencySetting = Foswiki::Func::getPreferencesValue('NOTIFY_AFFECTED', $dependencyWeb);
            $dependencySetting = Foswiki::Func::getPreferencesValue('NOTIFY_AFFECTED') unless defined $dependencySetting;
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

            my $affectedSetting = $affectedMeta->getPreference('NOTIFY_ABOUT_DEPENDENCIES');
            unless(defined $affectedSetting) {
                $affectedSetting = Foswiki::Func::getPreferencesValue('NOTIFY_ABOUT_DEPENDENCIES', $web);
                $affectedSetting = Foswiki::Func::getPreferencesValue('NOTIFY_ABOUT_DEPENDENCIES') unless defined $affectedSetting;
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

        $webtopic =~ s#\.#/#g; # we need slashes for links
        foreach my $responsible ( keys %$mails ) {
            Foswiki::Contrib::MailTemplatesContrib::sendMail('affectedmail', { IncludeCurrentUser => 0 }, {AffectedTopicResponsible => $responsible, AffectedWebTopicList => $mails->{$responsible}, AffectedDependency => $webtopic, LANGUAGE => $data->{LANGUAGE}}, 1) unless $responsible eq $lastProcessor;
        }
    },
};
