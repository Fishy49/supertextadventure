ready(function(){
  let dismissibles = document.getElementsByClassName('close');

  for (var i=0, len=dismissibles.length|0; i<len; i=i+1|0) {
    dismissibles[i].addEventListener('click', function(e){
      e.target.closest('.alert').parentNode.removeChild(e.target.closest('.alert'));
    });
  }
});
