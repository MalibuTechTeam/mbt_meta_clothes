$(function () {
    let isUiBusy = false;

    display = function (bool) {
        if (bool) {
            $("#main-div").css("display", " flex");
            $("#main-div").show();
        } else {
            $("#main-div").hide();
        }
    };

    wearableStatus = function (mask, bag, armor) {
        mask == true ? $("#mask").css("display", "flex") : $("#mask").hide();
        bag == true ? $("#bag").css("display", "flex") : $("#bag").hide();
        armor == true ? $("#bulletproof").css("display", "flex") : $("#bulletproof").hide();
    };

    hideClothes = function (index) {
        const elements = { 4: "#trousers", 6: "#shoes", 7: "#chain", 8: "#shirt" };
        const elementToHide = elements[index];
        if (elementToHide) { $(elementToHide).hide(); }
    }

    showClothes = function (index) {
        const elements = { 4: "#trousers", 6: "#shoes", 7: "#chain", 8: "#shirt" };
        const elementToShow = elements[index];
        if (elementToShow) { $(elementToShow).show(); }
    }

    hideProps = function (index) {
        const elements = { 0: "#hat", 1: "#glasses", 2: "#earaccessories", 6: "#watch" };
        const elementToHide = elements[index];
        if (elementToHide) { $(elementToHide).hide(); }
    }

    showProps = function (index) {
        const elements = { 0: "#hat", 1: "#glasses", 2: "#earaccessories", 6: "#watch" };
        const elementToShow = elements[index];
        if (elementToShow) { $(elementToShow).show(); }
    }

    showArmorCircle = function (bool) {
        if (bool) {
            const targetElement = document.getElementById('armorCircle');
            targetElement.innerHTML = '<g><g><circle class="st1" cx="330" cy="530" r="45.4" /><radialGradient id="SVGID_9_" cx="601.9263" cy="323.2976" r="53.6217" gradientUnits="userSpaceOnUse"><stop offset="0.5806" style="stop-color:#2a2a2a"/><stop offset="0.8178" style="stop-color:#2a2a2a" /><stop offset="0.9032" style="stop-color:#2a2a2a" /><stop offset="0.9638" style="stop-color:#2a2a2a" /><stop offset="1" style="stop-color:#2a2a2a" /></radialGradient><circle class="st13" cx="330" cy="530" r="36.6" /></g><g class="st20" onclick="handleUndress(7)" transform="translate(305.000000,555.000000) scale(0.020000,-0.020000)" fill="#d1dede" stroke="none"><path d="M720 2413 c-47 -19 -89 -39 -94 -43 -7 -7 135 -378 160 -422 4 -7 170 57 187 72 7 6 -133 367 -161 416 -5 9 -30 3 -92 -23z"/> <path d="M1662 2240 l-91 -211 62 -28 c97 -42 127 -54 132 -49 13 13 175 403 172 412 -3 6 -42 27 -88 46 -45 19 -86 36 -89 38 -4 1 -48 -92 -98 -208z"/> <path d="M930 2403 c0 -3 39 -100 86 -215 47 -116 83 -213 79 -216 -13 -13 -355 -149 -359 -143 -3 4 -41 97 -86 206 -45 110 -85 203 -89 208 -4 4 -15 1 -24 -5 -16 -12 -15 -18 17 -78 113 -212 81 -471 -79 -647 l-55 -61 0 -86 0 -86 235 0 235 0 0 -200 0 -200 -235 0 -235 0 0 -30 0 -30 235 0 235 0 0 -200 0 -200 -235 0 -236 0 3 -97 3 -98 36 -17 c57 -29 180 -56 332 -75 179 -22 770 -25 942 -5 157 19 303 49 355 75 l45 22 3 98 3 97 -236 0 -235 0 2 198 3 197 233 3 232 2 0 30 0 30 -235 0 -235 0 0 200 0 200 235 0 235 0 0 86 0 86 -54 59 c-96 106 -146 238 -146 382 0 98 21 181 67 270 20 37 34 69 32 71 -2 2 -13 6 -24 9 -18 6 -30 -16 -109 -203 -49 -116 -94 -210 -101 -210 -13 0 -336 138 -347 149 -4 3 34 100 83 214 49 115 89 211 89 213 0 2 -6 4 -14 4 -8 0 -43 -29 -78 -63 -81 -82 -150 -111 -258 -111 -109 1 -178 30 -258 111 -56 55 -92 77 -92 56z"/> <path d="M337 1183 c-4 -3 -7 -51 -7 -105 l0 -98 230 0 230 0 0 105 0 105 -223 0 c-123 0 -227 -3 -230 -7z"/> <path d="M1770 1085 l0 -105 230 0 231 0 -3 103 -3 102 -227 3 -228 2 0 -105z"/> <path d="M330 615 l0 -105 230 0 230 0 0 105 0 105 -230 0 -230 0 0 -105z"/> <path d="M1770 615 l0 -105 230 0 230 0 0 105 0 105 -230 0 -230 0 0 -105z"/></g></g>';
        }
    }

    showBagCircle = function (bool) {
        if (bool) {
            const targetElement = document.getElementById('bagCircle');
            targetElement.innerHTML = '<g><g><circle class="st1" cx="475" cy="530" r="45.4" /><radialGradient id="SVGID_9_" cx="601.9263" cy="323.2976" r="53.6217" gradientUnits="userSpaceOnUse"><stop offset="0.5806" style="stop-color:#2a2a2a"/><stop offset="0.8178" style="stop-color:#2a2a2a" /><stop offset="0.9032" style="stop-color:#2a2a2a" /><stop offset="0.9638" style="stop-color:#2a2a2a" /><stop offset="1" style="stop-color:#2a2a2a" /></radialGradient><circle class="st14" cx="475" cy="530" r="36.6" /></g><g class="st20" onclick="handleUndress(7)" transform="translate(452.000000,550.000000) scale(0.018000,-0.018000)" fill="#d1dede" stroke="none"><path d="M1224 2309 c-145 -17 -327 -127 -536 -326 l-77 -73 215 0 214 0 59 40 c134 91 228 92 361 1 l60 -41 212 0 213 1 -88 84 c-254 242 -442 335 -633 314z"/><path d="M380 1776 c-105 -23 -183 -85 -229 -179 -29 -59 -33 -86 -92 -581 -55 -467 -60 -524 -49 -573 16 -73 62 -131 135 -168 l59 -30 1075 0 1076 0 53 24 c67 30 118 89 139 161 16 54 15 64 -57 675 l-72 620 -36 33 -35 32 -956 -1 c-713 0 -970 -4 -1011 -13z"/></g></g>';
        }
    }

    // Spaghetti Code
    checkPlayerClothes = function (clothes, defaultIndexClothes, defaultIndexProps, playerSex) {
        var clothesKeyList = ["Arms", "Legs", "Foot", "Torso Accessories", "TShirt", "Jacket"];
        var propsKeyList = ["Hats", "Glasses", "Ear Accessories", "Watch"];
        var clothesFilter = clothes.Drawables.filter(function (value) { return value !== null; });
        var clothesProps = Object.values(clothes.Props);
        var propsFilter = clothesProps.filter(function (value) { return value !== null; });
        var clothesIndex = [3, 4, 6, 7, 8, 11]
        var propsIndex = [0, 1, 2, 6]
        var newClothes = {};
        var newProps = {};
        var newDefaultClothes = {};
        var newDefaultProps = {};

        for (var i = 0; i < propsFilter.length; i++) {
            if (propsFilter[i] != null) {
                var key = propsKeyList[i];
                var value = propsFilter[i];
                newProps[key] = value;
            }
        }

        for (var i = 0; i < Object.values(defaultIndexProps).length; i++) {
            if (defaultIndexProps[i] != null) {
                var key = defaultIndexProps[i].Label;
                var value = defaultIndexProps[i].Default[playerSex];
            } else if (defaultIndexProps[6]) {
                var key = defaultIndexProps[6].Label;
                var value = defaultIndexProps[6].Default[playerSex];
            }
            newDefaultProps[key] = value;
        }

        for (var i = 0; i < clothesFilter.length; i++) {
            if (clothesFilter[i] != null) {
                var key = clothesKeyList[i];
                var value = clothesFilter[i];
                newClothes[key] = value;
            }
        }

        for (var i = 0; i < defaultIndexClothes.length; i++) {
            if (defaultIndexClothes[i] != null) {
                var key = defaultIndexClothes[i].Label;
                var value = defaultIndexClothes[i].Default[playerSex];
                newDefaultClothes[key] = value;
            }
        }

        compareClothes(newClothes, newDefaultClothes, clothesIndex);
        compareProps(newProps, newDefaultProps, propsIndex);
    }

    compareClothes = function (obj1, obj2, index) {
        var valori1 = Object.values(obj1);
        var valori2 = Object.values(obj2);

        if (valori1.length !== valori2.length) { return false; }

        for (var i = 0; i < valori1.length; i++) {
            if (valori1[i] !== valori2[i][0]) {
                i == 4 || i == 5 ? showClothes(8) : showClothes(index[i]);
            } else {
                i == 4 || i == 5 ? hideClothes(8) : hideClothes(index[i]);
            }
        }
    }

    compareProps = function (obj1, obj2, index) {
        var valori1 = Object.values(obj1);
        var valori2 = Object.values(obj2);

        if (valori1.length !== valori2.length) { return false; }

        for (var i = 0; i < valori1.length; i++) {
            valori1[i] !== valori2[i][0] ? showProps(index[i]) : hideProps(index[i]);
        }
    }

    window.addEventListener("message", function (event) {
        var item = event.data;
        switch (item.action) {
            case "ui":
                display(item.status);
                wearableStatus(item.mask, item.bag, item.armor);
                showArmorCircle(item.wearableProps);
                showBagCircle(item.wearableProps);
                break;
            case "sendUiState":
                isUiBusy = item.status;
                break;
            case "applyDress":
                showClothes(item.indexDress)
                break;
            case "applyProps":
                showProps(item.indexProp)
                break;
            case "checkPlayerClothes":
                checkPlayerClothes(item.clothes, item.defaultIndexCLothes, item.defaultIndexProps, item.playerSex);
                break;
            default:
                break;
        }
    });

    window.addEventListener("keyup", (e) => {
        e.preventDefault();
        if (e.key === "Escape") {
            $("#main-div").hide();
            $.post("https://mbt_meta_clothes/exitUI", JSON.stringify({}));
        }
    });

    handleUndress = function (index) {
        if (!isUiBusy) {
            isUiBusy = true;
            $.post(
                `https://mbt_meta_clothes/handleDress`,
                JSON.stringify({
                    Index: index
                })
            );
            hideClothes(index);
        }
    };

    handleProps = function (index) {
        if (!isUiBusy) {
            isUiBusy = true;
            $.post(
                `https://mbt_meta_clothes/handleProps`,
                JSON.stringify({
                    Index: index
                })
            );
            hideProps(index);
        }
    };

    $(".st0").click(function () {
        $(".one").toggleClass("show");
    });

    $(".st1").click(function () {
        $(".two").addClass("show");
    });

    $(".st2").click(function () {
        $(".three").toggleClass("show");
    });

    $(".st3").click(function () {
        $(".four").toggleClass("show");
    });

    $(".close").click(function () {
        $(".info").removeClass("show");
    });
});
