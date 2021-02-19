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
//= require jquery3
//= require popper
//= require bootstrap-sprockets
//
//= require turbolinks
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


let textarea = document.getElementById('test');


$(document).ready(function() {
  $('.drawer').drawer();
});





$(function() {
    // ロード時に県が選ばれているとき
    $('#search_prefecture').each(function() {
      pr_name = $(this).val();
      append_city_option(pr_name);
    })

    // select_boxが選択された時
    $(document).on('change', '#search_prefecture', function() {
      pr_name = $(this).val();
      append_city_option(pr_name);
    })

    function append_city_option(pr_name) {
      if (pr_name == "") {
        // 選択肢の入れ替え
        $('#search_city option').remove();
        let $option_tag = $('<option>').val("").text("選択してください");
        $('#search_city').append($option_tag);
      } else {
        let pr_code = get_pr_code(pr_name);
        // APIでcityを取得
        $.ajax({
          type: "GET",
          url: `https://www.land.mlit.go.jp/webland/api/CitySearch?area=${pr_code}`
        }).done(function (json) {
          let data = json['data']
          let city_list = [...data].map(value => value.name);
          // 選択肢の入れ替え
          $('#search_city option').remove();
          let $option_tag = $('<option>').val("").text("選択してください");
          $('#search_city').append($option_tag);
          city_list.forEach(function (name) {
            let $option_tag = $('<option>').val(name).text(name);
            $('#search_city').append($option_tag);
          });
          // ロード時に1回だけ，クエリにあるcityを選択する
          if (!$('#search_city').hasClass('fire')) {
            let path_search = location.search;
            let selected_city = decodeURI(path_search.match(/city_or_town_cont%.*/g)[0].replace('city_or_town_cont%5D=', '').replace('&commit=%E6%A4%9C%E7%B4%A2',''));
            $('#search_city').val(selected_city);
            $('#search_city').addClass('fire');
          }
        }).fail(function () {
          alert('エラーが発生しました');
        })
      }
    }

    function get_pr_code(pr_name) {
      let prefecture = ["北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県", "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県", "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県", "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"]
      let index = prefecture.indexOf(pr_name) + 1
      let pr_code = ("0" + index).slice(-2)
      return pr_code
    }
  });

  id_checkes = function(ele){
    ids = $("input[type='checkbox'].customer-checkbox").filter(":checked").map(function(){
      return $(this).attr("id");
    }).get();
    $("#customer-destroy-link").attr("href", "/companies/bulk_destroy?" + $.param({"ids":ids}));
    mails = $("input[type='checkbox'].customer-checkbox").filter(":checked").map(function(){
      return $(this).data()["email"];
    }).get();
    var params = $("#customer-mail-link").attr("href").split("?")[1]
    $("#customer-mail-link").attr("href", "mailto:" + mails.join(",") + "?" + params);
    // $("#customer-mail-link").attr("href", "/companies/mail?" + $.param({"mails":mails}));
    customer_ids = $("input[type='checkbox'].customer-checkbox").filter(":checked").map(function(){
      return $(this).data()["customerId"];
    }).get();
    $("#customer-destroy-link").attr("href", "/customers/bulk_destroy?" + $.param({"ids":customer_ids}));
    $("#customer-uploads-link").attr("href", "/customers/bulk_edit?" + $.param({"ids":customer_ids}));


  }


  $(document).on('turbolinks:load', function(event) {
  //$(document).on('ready', function(event) {
          //customer/:id
      $(document).on("click", ".edit-link-show", function () {
        data = $(this).data()
        $("#" + data.v + "-show").addClass("none")
        $("#" + data.v + "-c-input-field").removeClass("none")
      });
      $(".c-input-field").keypress( function ( e ) {
      	if ( e.which == 13 ) {
          x = $('#customer-show-update').submit();
      	}
      } );
      $(".c-input-field2").keypress( function ( e ) {
      	if ( e.which == 13 ) {
          x = $('#customer-show-update2').submit();
      	}
      } );
      $(document).on("keypress", ".t-input-field", function (e) {
        if ( e.which == 13 ) {
          x = $('#todo-show-update').submit();
      	}
      });
      $(document).on("click", ".customer-edit", function () {
        data = $(this).data()
        $("#" + data.id + "-customer-body").toggle();
        $("#" + data.id + "-customer-edit-field").toggle();
      })

      $(document).on("click", ".customer-edit-detail", function () {
        data = $(this).data()
        $("#" + data.id + "-customer-edit-detail-field").toggle();
      })

      $(document).on("change", "#form-bulk-edit", function () {
        $(".form-bulk-edit-input").addClass("none")
        v = $(this).val()
        $("#form-" + v).removeClass("none")
      })



      $("#customer-index-table").tablesorter();
      $(".customer-checkbox").change(function(){
        id_checkes()
      });
      $(".all-customer-checkbox").click(function(){
        $('.admin-checkbox').prop('checked', this.checked);
        id_checkes()
      });
    })
