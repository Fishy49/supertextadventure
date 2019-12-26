import { ajax } from '@rails/ujs';
import qs from 'qs';

function submit_game_message(e){
  let evtobj = window.event ? event : e
  if(!evtobj.shiftKey && evtobj.keyCode == 13){
    ajax({
      type: 'POST',
      url: `/game_messages`,
      data: qs.stringify({
        game_message: {
          body: document.getElementById('game-message-input').value,
          game_id: document.getElementById('game').getAttribute('data-game-id'),
          meta: {}
        }
      }),
      dataType: 'json',
    });
    document.getElementById('game-message-input').value = '';
    return false;
  }
}

ready(function(){
  if(document.getElementById('game')){
    document.getElementById('game-message-input').onkeydown = submit_game_message;
  }
});
