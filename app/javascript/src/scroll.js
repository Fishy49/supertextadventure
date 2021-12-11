function attachListenersToGameMessageContainer() {
  if(document.getElementById('game_messages')){
    document.getElementById('game-messages-container').scrollTo({
      top: document.getElementById('game-messages-container').scrollHeight,
      behavior: 'smooth'
    });
    
    var observer = new MutationObserver(function( mutations ) {
      document.getElementById('game-messages-container').scrollTo({
        top: document.getElementById('game-messages-container').scrollHeight,
        behavior: 'smooth'
      });
    });

    observer.observe(document.getElementById('game_messages'), { childList: true, subtree: true });
  }
}

document.addEventListener('turbo:load', attachListenersToGameMessageContainer);
