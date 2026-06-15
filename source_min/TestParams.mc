using Toybox.Application as App;

class TestParams extends App.AppBase {
    function initialize(params) {
        if (params == null) params = {};
    }
}

var app = new TestParams();
