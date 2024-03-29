package Mojolicious::Plugin::SendEmail;
use v5.26;
use warnings;

# ABSTRACT: Easily send emails from Mojolicious applications

use Mojo::Base 'Mojolicious::Plugin';

use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use experimental qw(signatures);

sub register($self, $app, $conf = {}) {

  my $from = delete($conf->{from});
  my $rr   = delete($conf->{recipient_resolver}) // sub($add) { $add };
  delete($conf->{sasl_username}) unless(defined($conf->{sasl_username}));
  delete($conf->{sasl_password}) unless(defined($conf->{sasl_password}));

  my $transport = Email::Sender::Transport::SMTP->new($conf);

  $app->helper(send_email => sub ($c, %args) {
    my $mail = Email::Stuffer->new({
      transport => $transport,           # from config
      from      => $args{from} // $from, # from config, overridable
      to        => $rr->($args{to}),     # required
      subject   => $args{subject} // '', # optional, default empty string
    });
    $mail->cc($rr->($args{cc}))   if($args{cc});
    $mail->bcc($rr->($args{bcc})) if($args{bcc});
  
    my $body = '';
    if($args{template}) { 
      my $bs = $c->render_to_string(
        format   => 'mail',
        template => $args{template}, 
        ($args{params}//{})->%*
      );
      $body = $bs->to_string if($bs);
    } elsif($args{body}) {
      $body = $args{body};
    }
    if($args{html}) {
      $mail->html_body($body)
    } else {
      $mail->text_body($body)
    }

    foreach my $header (($args{headers}//[])->@*) {
      $mail->header($header->%*);
    }

    $mail->send();
  });

}

1;
