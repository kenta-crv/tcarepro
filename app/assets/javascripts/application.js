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
//
//= require chartkick
//= require Chart.bundle
//= require popper
//= require rails-ujs
//= require turbolinks
//= require jquery
//= require_tree .
//


$(function() {
  $('.navToggle').click(function() {
      $(this).toggleClass('active');

      if ($(this).hasClass('active')) {
          $('.globalMenuSp').addClass('active');
      } else {
          $('.globalMenuSp').removeClass('active');
      }
  });
});


var textarea = document.getElementById('test');


$(document).ready(function() {
$('.drawer').drawer();
});





document.addEventListener("DOMContentLoaded", function() {
    // すべてのチェックボックスを取得
    var checkboxes = document.querySelectorAll('.cp_qa .cp_actab input[type="checkbox"]');

    // 各チェックボックスに対するイベントリスナーを設定
    checkboxes.forEach(function(checkbox) {
        checkbox.addEventListener('change', function() {
            var content = this.nextElementSibling.nextElementSibling; // .cp_actab-content要素を取得

            if (this.checked) {
                // チェックされた場合、.cp_actab-contentの高さを設定
                var height = content.scrollHeight + "px";
                content.style.maxHeight = height;
            } else {
                // チェックが外れた場合、高さをリセット
                content.style.maxHeight = null;
            }
        });
    });
});

$(document).ready(function(){
    // アコーディオンをクリックしたときのイベント
    $('.cp_actab label').click(function(e){
      var currentAttrValue = $(this).attr('for');
  
      if($('#' + currentAttrValue).is(':checked')){
        // アコーディオンを閉じる
        close_accordion_section();
      }else {
        // アコーディオンを開く
        close_accordion_section();
  
        // クリックしたアコーディオンのセクションを追加
        $(this).toggleClass('active');
        $('#' + currentAttrValue).prop('checked', true);
  
        // 高さを設定
        var content = $(this).next('.cp_actab-content');
        content.css('max-height', content.prop('scrollHeight') + 'px');
      }
  
      e.preventDefault();
    });
  
    function close_accordion_section() {
      $('.cp_actab input[type="checkbox"]').prop('checked', false);
      $('.cp_actab-content').css('max-height', '0');
    }
  });
  