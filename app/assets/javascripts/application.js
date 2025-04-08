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

document.addEventListener("turbolinks:load", function() {
    $('#worker').modal('show');
  });