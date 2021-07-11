function hotKeyTrigger(e) {
  console.log("OK")
  console.log(e.key)
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
    }
  }
}

document.addEventListener('keydown', hotKeyTrigger, false);
