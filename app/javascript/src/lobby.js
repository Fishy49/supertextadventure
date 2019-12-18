import { ajax } from '@rails/ujs';
import qs from 'qs';

let fetch_games_list = function(){
  let filters = {}
  let filter_triggers = document.getElementsByClassName('filter-trigger')
  for (var i=0, len=filter_triggers.length|0; i<len; i=i+1|0) {
    let filter_input = filter_triggers[i].querySelector('input');
    if(filter_input.checked){
      filters[filter_input.name] = 1;
    }
  }

  ajax({
    type: 'GET',
    url: `/games`,
    data: qs.stringify(filters),
    dataType: 'script',
  });
}

ready(function(){
  if(document.getElementsByClassName('lobby-container').length > 0){
    loading(document.getElementsByClassName('games-loading')[0]);

    fetch_games_list();

    let filter_triggers = document.getElementsByClassName('filter-trigger')
    for (var i=0, len=filter_triggers.length|0; i<len; i=i+1|0) {
      filter_triggers[i].querySelector('input').addEventListener('change', fetch_games_list);
    }
  }
});
