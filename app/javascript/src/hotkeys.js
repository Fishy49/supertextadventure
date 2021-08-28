function hotKeyTrigger(e) {
  if (e.ctrlKey) {
    switch(e.key) {
      case 'h':
        document.location.href = '/'
        break;
      case 'l':
        if(confirm("Logout?")){
          document.location.href = "/logout"
        }
        break;
      case 'g':
        document.location.href = "/games"
        break;
      case 'c':
        document.location.href = "/characters"
        break;
      case 'a':
        document.location.href = "/about"
        break;
    }
  }
}

window.addEventListener('keydown', hotKeyTrigger, false);
