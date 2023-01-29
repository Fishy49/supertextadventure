// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// https://stackoverflow.com/a/49077414
window.beep = function(vol, freq, duration){
  if(!window.audio_context){
    window.audio_context = new AudioContext();
  }
  
  let v = window.audio_context.createOscillator()
  let u = window.audio_context.createGain()

  v.connect(u)
  v.frequency.value=freq
  v.type="sawtooth"
  u.connect(window.audio_context.destination)
  u.gain.value=vol*0.01
  v.start(window.audio_context.currentTime)
  v.stop(window.audio_context.currentTime+duration*0.001)
}

// https://stackoverflow.com/a/4238971
window.placeCaretAtEnd = function(el) {
  if (typeof window.getSelection != "undefined"
          && typeof document.createRange != "undefined") {
    let range = document.createRange();
    range.selectNodeContents(el);
    range.collapse(false);
    let sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
  } else if (typeof document.body.createTextRange != "undefined") {
    let textRange = document.body.createTextRange();
    textRange.moveToElementText(el);
    textRange.collapse(false);
    textRange.select();
  }
}

