// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//
//= require jquery_ujs
//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require dropzone
//
//= require turbolinks
//= require_tree .
//

/*
* #TPD
* #2018.12.14
* bootstrap DateTImePicker 設定 #2018.12.14
*/

let textarea = document.getElementById('test');


$(document).ready(function() {
  $('.drawer').drawer();
});


Dropzone.autoDiscover = false

new Dropzone '#upload-dropzone',
  uploadMultiple: false
  paramName: 'uploader[file]'
  params:
    'uploader[document_id]': 123
  init: ->
    @on 'success', (file, json) ->
      # アップロード成功時の処理をここに実装します。
  dictDefaultMessage: '''
    <i class="fa fa-file-o fa-2x"></i><br>
    <br>
    ファイルをここにドロップするか<br>
    ここをクリックして下さい
  '''
