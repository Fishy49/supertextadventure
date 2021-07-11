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
    }
  }
}

document.addEventListener('keydown', hotKeyTrigger, false);
