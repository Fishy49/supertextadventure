import { extend } from 'lodash';

// http://youmightnotneedjquery.com/#ready
let ready = function(fn) {
  if (document.readyState != 'loading'){
    fn();
  } else {
    document.addEventListener('DOMContentLoaded', fn);
  }
}

// https://codepen.io/rileyjshaw/pen/ABzsc
let loading = function (el, i = 0) {
  if(!el) return false;
  let seq = [
    'Loading',
    '=Loading=',
    '==Loading==',
    '-==Loading==-',
    '--==Loading==--',
    '--== Loading ==--',
    '--== Loading ==--',
    '--==Loading==--',
    '-==Loading==-',
    '==Loading==',
    '=Loading=',
    'Loading',
  ]

  el.innerText = seq[i %= seq.length];
  return setTimeout(loading, 150, el, ++i);
};

extend(window, {
  ready,
  loading
});
