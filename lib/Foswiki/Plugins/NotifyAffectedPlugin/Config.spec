# ---+ Extensions
# ---++ NotifyAffectedPlugin

# **STRING**
# The user in this formfield will get notified. Defaults to 'Responsible'.
$Foswiki::cfg{Plugins}{NotifyAffectedPlugin}{Formfield} = '';

# **STRING**
# (Optional) Only notify, when this condition is true. TML; will be expanden it the context of the topic.
# Defaults to: <pre>%<nop>IF{"&#36;'GETWORKFLOWROW{approved}'" then="1"}%</pre>
$Foswiki::cfg{Plugins}{NotifyAffectedPlugin}{Condition} = '';
