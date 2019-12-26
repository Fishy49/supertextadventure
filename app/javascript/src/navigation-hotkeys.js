function key_press(e) {
  var evtobj = window.event ? event : e
  if(evtobj.ctrlKey){
    switch(evtobj.keyCode){
      case 72:
        window.location.href = '/'
        break;
      case 70:
        window.location.href = '/friends'
        break;
      case 67:
        window.location.href = '/characters'
        break
      case 71:
        window.location.href = '/lobby'
        break
      case 83:
        window.location.href = '/settings'
        break
    }
  }
}

document.onkeydown = key_press;
