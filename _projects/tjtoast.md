---
layout: projects
title: tjToast
date: 2015-10-11
desc: "Toast aka Flash Message support for Angular JS apps"
src: https://github.com/brinkt/angular-tj-toast
demo: https://brinkt.github.io/angular-tj-toast/
tags2: angularjs javascript gulp
---

![tjToast Demo](/assets/tjToast-demo.gif "tjToast Demo")

Features:
* allows multiple toasts to be enqueued
* toasts can be displayed immediately or at a later time, such as after a view change
* must cycle through the toasts queue deliberately with `tjToast.now()`
* expects only one listening directive `<tj:toast></tj:toast>` within DOM
