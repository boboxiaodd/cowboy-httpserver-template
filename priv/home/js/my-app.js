var pathbase = "http://app.xiaodd.com:9000";
var osspath = "";
var app = new Framework7({
    // App root element
    root: '#app',
    // App Name
    name: '后台管理系统',
    // App id
    id: 'com.myapp.test',
    touch: {
        // Enable fast clicks
        fastClicks: true,
    },
    // Add default routes
    routes: [
        {
            path: '/package/:id/:name/',
            componentUrl: './pages/package.html?v='+version
        },
        {
            path: '/home/',
            componentUrl: './pages/home.html?v='+version
        }
    ],
    // ... other parameters
});
var $$ = Dom7;
Framework7.request.setup({
    crossDomain: true
})

var mainView;

$$('#password').on('submit',function () {
    $$('#btnLogin').click();
    return false;
})
$$('#btnLogin').on('click', function () {
    var pass = $$("#password").val();
    if (pass == "") {
        app.dialog.alert("请输入共享密码!", "错误");
    } else {
        app.request.postJSON(pathbase + "/api/package/login", {
                password: md5(pass)
            },
            function (data, status, xhr) {
                if (data.ok == 1) {
                    osspath = data.path+"/";
                    Framework7.request.setup({
                        crossDomain: true,
                        headers: {
                            'Authorization': 'bear ' + data.token
                        }
                    });
                    mainView = app.views.create('.view-main', {
                        url: '/home/'
                    });
                    loginScreen.close();
                } else {
                    app.dialog.alert(data.msg, "错误");
                }
            },
            function (xhr, status) {
                console.log(status)
            }
        )
    }
})
var loginScreen = app.popup.create({
    el: '.login-screen',
    closeByBackdropClick: false,
    on: {
        opened: function () {
            console.log('Login Screen opened')
        },
        closed: function () {
            console.log('Login Screen closed')
        }
    }
});
setTimeout(function () {
    loginScreen.open();
}, 300);

function request_uri(path, json, callback) {
    app.request.postJSON(pathbase + path, json,
        function (data, status, xhr) {
            if (data.ok == 1) {
                callback(data);
            } else {
                app.dialog.alert(data.msg, "错误");
            }
        },
        function (xhr, status) {
            app.dialog.alert(status, "错误");
            app.preloader.hide();
        }
    )
}

function formatDate(time) {
    var date = new Date(time);
    var y = 1900 + date.getYear();
    var m = "0" + (date.getMonth() + 1);
    var d = "0" + date.getDate();
    var h = "0" + date.getHours();
    var M = "0" + date.getMinutes();
    return y + "-" + m.substring(m.length - 2, m.length) + "-" + d.substring(d.length - 2, d.length) +
        " "+ h.substring(h.length - 2, h.length) +
        ":"+ M.substring(M.length - 2, M.length);
}

function getDateDiff(ts) {
    if (!ts) return "";
    if (ts > 100000000000) {
        ts = Math.round(ts / 1000000);
    }
    var publishTime = ts;
    var d_seconds,
        d_minutes,
        d_hours,
        d_days,
        timeNow = parseInt(new Date().getTime() / 1000),
        d,
        
        date = new Date(publishTime * 1000),
        Y = date.getFullYear(),
        M = date.getMonth() + 1,
        D = date.getDate(),
        H = date.getHours(),
        m = date.getMinutes(),
        s = date.getSeconds();
    //小于10的在前面补0
    if (M < 10) {
        M = '0' + M;
    }
    if (D < 10) {
        D = '0' + D;
    }
    if (H < 10) {
        H = '0' + H;
    }
    if (m < 10) {
        m = '0' + m;
    }
    if (s < 10) {
        s = '0' + s;
    }
    
    d = timeNow - publishTime;
    d_days = parseInt(d / 86400);
    d_hours = parseInt(d / 3600);
    d_minutes = parseInt(d / 60);
    d_seconds = parseInt(d);
    
    if (d_days > 0 && d_days < 3) {
        return d_days + '天前';
    } else if (d_days <= 0 && d_hours > 0) {
        return d_hours + '小时前';
    } else if (d_hours <= 0 && d_minutes > 0) {
        return d_minutes + '分钟前';
    } else if (d_seconds < 60) {
        if (d_seconds <= 0) {
            return '刚刚';
        } else {
            return d_seconds + '秒前';
        }
    } else  {
        return d_days+' 天前';
    }
}
