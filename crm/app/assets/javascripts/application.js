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
//= require jquery
//= require jquery_ujs
//= require_self
//= require popper
//= require bootstrap-sprockets
//
//= require turbolinks
//= require_tree .
//
$(function() {
  $('.header-right').hover(function() {
    $("header-right:not(:animated)", this).slideDown();
  }, function() {
    $(".child").slideUp();
  });
});

$(function() {
  //ログインをクリックした際にフェードイン
  $('#login-show').click(function() {
    $('#login-show').fadeIn();
  });

  //新規登録をクリックした際にフェードイン
  $('.signup-show').click(function() {
    $('#signup-modal').fadeIn();
  });

  //新規登録とログインを閉じる時のフェードアウト
  $('.close-modal').click(function() {
    $('#login-modal').fadeOut();
    $('#signup-modal').fadeOut();
  });
});


id_checkes = function(ele){
  ids = $("input[type='checkbox'].company-checkbox").filter(":checked").map(function(){
    return $(this).attr("id");
  }).get();
  $("#company-destroy-link").attr("href", "/companies/bulk_destroy?" + $.param({"ids":ids}));
  mails = $("input[type='checkbox'].company-checkbox").filter(":checked").map(function(){
    return $(this).data()["email"];
  }).get();
  var params = $("#company-mail-link").attr("href").split("?")[1]
  $("#company-mail-link").attr("href", "mailto:" + mails.join(",") + "?" + params);
  // $("#company-mail-link").attr("href", "/companies/mail?" + $.param({"mails":mails}));
  comment_ids = $("input[type='checkbox'].company-checkbox").filter(":checked").map(function(){
    return $(this).data()["commentId"];
  }).get();
  console.log(comment_ids)
  $("#comment-destroy-link").attr("href", "/comments/bulk_destroy?" + $.param({"ids":comment_ids}));
  $("#comment-uploads-link").attr("href", "/comments/bulk_update?" + $.param({"ids":comment_ids}));


}


//takigawa
$(document).on('turbolinks:load', function(event) {
//$(document).on('ready', function(event) {
        //company/:id
    $(document).on("click", ".edit-link-show", function () {
      data = $(this).data()
      $("#" + data.v + "-show").addClass("none")
      $("#" + data.v + "-c-input-field").removeClass("none")
    });
    $(".c-input-field").keypress( function ( e ) {
    	if ( e.which == 13 ) {
        x = $('#company-show-update').submit();
    	}
    } );
    $(".c-input-field2").keypress( function ( e ) {
    	if ( e.which == 13 ) {
        x = $('#company-show-update2').submit();
    	}
    } );
    $(document).on("click", ".comment-edit", function () {
      data = $(this).data()
      $("#" + data.id + "-comment-body").toggle();
      $("#" + data.id + "-comment-edit-field").toggle();
    })
        $(document).on("click", ".comment-edit-detail", function () {
      data = $(this).data()
      $("#" + data.id + "-comment-edit-detail-field").toggle();
    })


    $("#company-index-table").tablesorter();
    $(".company-checkbox").change(function(){
      id_checkes()
    });
    $(".all-company-checkbox").click(function(){
      $('.admin-checkbox').prop('checked', this.checked);
      id_checkes()
    });

    $(".modal-backdrop").click(function(){
      console.log("Hi")
      $("#company-modal").modal("fade")
      $("#company-modal").modal("hide")
      $("#company-modal").modal("hidden")
    });

});
