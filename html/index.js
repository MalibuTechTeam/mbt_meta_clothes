$(function() {
  let isUiBusy = false;

  display = function(bool) {
      if (bool) {
          $("#main-div").css("display", " flex");
          $("#main-div").show();
      } else {
          $("#main-div").hide();
      }
  };

  window.addEventListener("message", function(event) {
      var item = event.data;
      if (item.action === "ui") {
          display(item.status);
      } else if (item.action === "sendUiState") {
          isUiBusy = item.status;
      }
  });

  window.addEventListener("keyup", (e) => {
      e.preventDefault();
      if (e.key === "Escape") {
          $("#main-div").hide();
          $.post("https://mbt_meta_clothes/exitUI", JSON.stringify({}));
      }
  });

  handleUndress = function(index) {
      if (!isUiBusy) {
          isUiBusy = true;
          $.post(
              `https://mbt_meta_clothes/handleDress`,
              JSON.stringify({
                  Index: index
              })
          );
      }
  };

  handleProps = function(index) {
      if (!isUiBusy) {
          isUiBusy = true;
          $.post(
              `https://mbt_meta_clothes/handleProps`,
              JSON.stringify({
                  Index: index
              })
          );
      }
  };

  $(".st0").click(function() {
      $(".one").toggleClass("show");
  });

  $(".st1").click(function() {
      $(".two").addClass("show");
  });

  $(".st2").click(function() {
      $(".three").toggleClass("show");
  });

  $(".st3").click(function() {
      $(".four").toggleClass("show");
  });

  $(".close").click(function() {
      $(".info").removeClass("show");
  });
});
