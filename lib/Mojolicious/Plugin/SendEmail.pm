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
    my $unarray = sub ($x) { ref($x) eq 'ARRAY' ? $x->@* : $x };
    $mail->cc($unarray->($rr->($args{cc})))   if($args{cc});
    $mail->bcc($unarray->($rr->($args{bcc}))) if($args{bcc});
  
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
    $args{html} = index($body, '<html') != -1 unless(defined($args{html}));
    if($args{html}) {
      $mail->html_body($body)
    } else {
      $mail->text_body($body)
    }

    foreach my $header (($args{headers}//[])->@*) {
      $mail->header($header->%*);
    }

    foreach my $att (($args{attachments}//[])->@*) {
      if(ref($att) eq 'ARRAY') {
        $mail->attach($att->[0], ($att->[1]//{})->%*)
      } else {
        $mail->attach($att)
      }
    }

    foreach my $att (($args{files}//[])->@*) {
      if(ref($att) eq 'ARRAY') {
        $mail->attach_file($att->[0], ($att->[1]//{})->%*)
      } else {
        $mail->attach_file($att)
      }
    }
  });

}

1;
