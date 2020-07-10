---
layout: post
title: "Contact Form w/ reCAPTCHA & E-mail Delivery through Google Forms & Google Apps Scripts"
author: "brinkt"
date: 2018-10-29
tags: form recaptcha google-apps-scripts googlescript
---

This guide sets up a contact form with *reCAPTCHA* which submits to *Google Forms* and through *Google Sheets* and *Google Apps Scripts*, e-mails the contents of the form to a specified e-mail address. No backend code is necessary; works on *Github Pages*, *Google Sites*, etc.

This process is used in production on [https://nanobasis.com/contact](https://nanobasis.com/contact).

### Step 1: Register site with reCAPTCHA

Go to [https://www.google.com/recaptcha/admin](https://www.google.com/recaptcha/admin).

Create `reCAPTCHA v3` keys for your domain, accepting the *Terms of Service*.

Make note of your *Keys* and the instructions in *Step 1: Client side integration*.

### Step 2: Create a new Google Form

Go to [https://docs.google.com/forms](https://docs.google.com/forms).

Create a new form with **Name**, **E-mail Address**, and **Captcha** duplicated as *Short Answer* and **Details** as *Long Answer*.

From the vertical `...` menu on the very top right, click `Get pre-filled link`. Fill out the form with test data, click `Get Link`, then `Copy Link` on the notification tooltip.

Paste (Ctrl+v) into a text editor should reveal:

```
https://docs.google.com/forms/d/e/1FAIpQLSedjbJpryT29PkE6WHU1d2YAEopnYLFlYzoWTLwjoq30k-TdQ/viewform?usp=pp_url&entry.629821244=Test+Name&entry.2054212185=test@email.com&entry.1654889841=CAPTCHA&entry.692430337=Test+Details
```

Make note of the form id `1FAIpQLSedjbJpryT29PkE6WHU1d2YAEopnYLFlYzoWTLwjoq30k-TdQ` as well as each `entry.*` which matches up with *Name*, *E-mail Address*, *Captcha* and *Details* defined above.

In Google Forms **Responses** tab, click the **green spreadsheet icon** in the upper right.  Select `Create a new spreadsheet`, give it a name, and click *Create*.

A new browser tab to [https://docs.google.com/spreadsheets](https://docs.google.com/spreadsheets) should open.

Go to `Tools` menu, then `Script editor`.

A new browser tab to [https://script.google.com/macros](https://script.google.com/macros) should open.

### Step 3: Setup Google Apps Script

Go to `File` menu, `New`, then `New HTML file`.

Name the file **GoogleSheetsEmailer**, then click *OK*.

In `GoogleSheetsEmailer.html`, replace the entire contents with:

{% highlight html %}
<?= details ?>
<br><br>
<?= name ?>
<br>
<a href="mailto:<?= email ?>"><?= email ?></a>
{% endhighlight %}

In `Code.gs`, replace the entire contents with:

{% highlight javascript %}
// adjust these to your needs
var EMAIL_TO = 'contact@nanobasis.com';
var FORM_NAME = 'Online Contact Form';
var RECAPTCHA_SECRET_KEY = '';
var NO_REPLY = 'noreply@nanobasis.com';

function respondToFormSubmit(e) {
  if (!verifyCaptcha(e.namedValues['Captcha'])) {
    // if reCAPTCHA fails, do not send e-mail
    return;
  }

  // set e-mail subject & replyTo
  var subject = FORM_NAME;

  var em = e.namedValues['E-mail Address'];
  var replyTo = em && em != '' ? em : NO_REPLY;

  var fn = e.namedValues['Name'];
  if (fn && fn != '') {
    replyTo = fn + ' <' + replyTo + '>';
    subject = fn + ' : ' + subject;
  }

  // build e-mail template & assign template variables
  var template = HtmlService.createTemplateFromFile('GoogleSheetsEmailer');

  template.name = fn;
  template.email = em;
  template.details = e.namedValues['Details'];

  var message = template.evaluate();

  // send e-mail using MailApp
  MailApp.sendEmail({
    to: EMAIL_TO,
    subject: subject,
    replyTo: replyTo,
    htmlBody: message.getContent()
  });
}

// verify reCAPTCHA using UrlFetchApp
function verifyCaptcha(captcha){
  var resp = UrlFetchApp.fetch('https://www.google.com/recaptcha/api/siteverify?secret=' +
    RECAPTCHA_SECRET_KEY + '&response=' + captcha).getContentText();
  return JSON.parse(resp).success;
}

{% endhighlight %}

Adjust the variables `EMAIL_TO`, `FORM_NAME`, `NO_REPLY` to meet your needs and set `RECAPTCHA_SECRET_KEY` to the key created in *Step 1: Register site with reCAPTCHA*.

Save both `Code.gs` and `GoogleSheetsEmailer.html`.

### Step 4: Create Google Apps Script Trigger

Go to `Edit` menu, then `Current project's triggers`, then `No triggers set up. Click here to add one now.`

**Run**: *respondToFormSubmit*.

**Events**: *From spreadsheet* => *On form submit*.

Click *Save*.

A small browser window should open asking to allow this script access to your Google account. This account will be the one which e-mails the form to the desired `EMAIL_TO` address. Be sure to complete this process.

### Step 5: Create HTML Form

The following HTML form code uses [purecss.io](https://purecss.io) for styling, but can be adapted to fit your needs.

Make note that the form submits to `https://docs.google.com` and includes your form `id`.

Also note that each input is named `entry.*` and matches up with pre-filled link results taken from *Step 2: Create a new Google Form*.

The form `target="hiddenIf"` and corresponding `iframe` prevents the form submission from redirecting the browser to `https://docs.google.com`.

{% highlight html %}
<iframe name="hiddenIf" id="hiddenIf" style="display:none;"></iframe>

<form id="contact-form" target="hiddenIf" onsubmit="submitForm(event);" class="pure-form pure-form-stacked"
  action="https://docs.google.com/forms/d/e/1FAIpQLSedjbJpryT29PkE6WHU1d2YAEopnYLFlYzoWTLwjoq30k-TdQ/formResponse">

  <div>
    <label for="entry.629821244">Name</label>
    <input type="text" name="entry.629821244" class="pure-input-1"
      placeholder="Enter your name..." value="" required />
  </div>

  <div class="mar-t1">
    <label for="entry.2054212185">E-mail Address</label>
    <input type="email" name="entry.2054212185" class="pure-input-1"
      placeholder="Enter your email address..." value="" />
  </div>

  <div class="mar-t1">
    <label for="entry.692430337">Details</label>
    <textarea name="entry.692430337" rows="5" class="pure-input-1"
      placeholder="Start the conversation here..."></textarea>
  </div>

  <input id="google-recaptcha" type="hidden" name="entry.1654889841" value="" />

  <div class="mar-t1">
    <input id="button-submit" class="pure-button pure-button-primary" type="submit" value="Submit" disabled />
  </div>

</form>

<div id="contact-success"></div>

<script type="text/javascript">
  grecaptcha.ready(function() {
    grecaptcha.execute('6LewlHcUAAAAANs39m7L77fI8e-QYNREAeSY78fX', {action: 'contact_form'})
    .then(function(token) {
      // copy recaptcha response to hidden input
      document.getElementById('google-recaptcha').value = token;
      // enable form submit
      document.getElementById('button-submit').disabled = false;
    });
  });

  function submitForm(e) {
    var msg = 'Thank you for contacting us. We will get back to you shortly.';

    // simulate feel of connection with timeout
    setTimeout(function() {
      document.getElementById('contact-form').style.display = "none";
      document.getElementById('contact-success').innerHTML = msg;
    }, 300);
  }
</script>
{% endhighlight %}
