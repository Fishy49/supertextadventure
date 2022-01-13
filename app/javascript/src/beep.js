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
