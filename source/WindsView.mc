using Toybox.WatchUi as Ui;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.Lang as Lang;
using Toybox.System as System;
using Toybox.Timer as Timer;
using Toybox.Position as Position;
using Toybox.Attention as Attention;
using Toybox.Communications as Comm;

//
// WindsView displays Puget Sound wind information that is downloaded from
// Bob Hall's awesome obs website: http://b.obhall.com/obs
//
class WindsView extends CommonView {
    const SPEED_FONT = Graphics.FONT_NUMBER_MILD;
    const TITLE_FONT = Graphics.FONT_XTINY;
    const DIR_FONT = Graphics.FONT_MEDIUM;
    const WINDTIME_FONT = Graphics.FONT_XTINY;
    const MAX_SCREEN_WIDTH = 148;
    const MIN_SCREEN_HEIGHT = 205;
    //
    // windData gets the raw data that is downloaded from the internet
    // Fields:
    //   station_name -- What is the name of the wind station?
    //   wind_speed -- current wind speed
    //   wind_direction -- current wind direction
    //   time -- the time that this wind speed was recorded
    //   
    var windData = [];

    // what time did we last refresh the wind data?
    var lastDataRefresh;

    var screenBiasX = 0;
    var screenBiasY = 0;
    var speedFont = SPEED_FONT;

    //
    // initialize the view
    //
    function initialize() {
        CommonView.initialize("wind");
        lastDataRefresh = Time.today();
        highSpeedRefresh = false;

        // this whole view was written for the VA HR screen and these are hacks to make
        // it work on newer round watches
        screenBiasX = (screenWidth - MAX_SCREEN_WIDTH) / 2;
        screenWidth = MAX_SCREEN_WIDTH;
        screenBiasY = ((screenHeight - MIN_SCREEN_HEIGHT) / 2) + 20;

        // override the clock font
        clockSpeedFont = WINDTIME_FONT;
    }

    //
    // called when we need to reduce system memory to avoid hitting "out of objects"
    //
    function reduceMemory()
    {
        System.println("reduce memory: " + viewName);
        windData = [];
    }

    //
    // add a reload option to the menu
    //
    function addViewMenuItems(menu)
    {
        menu.addItem(new Ui.MenuItem("Reload", "Reload Wind Data", :reload, {}));
    }

    // 
    // handle menu items
    //
    function viewMenuItemSelected(symbol, item)
    {
        if (symbol == :reload)
        {
            requestWindData();
            Ui.popView(Ui.SLIDE_DOWN);
            return true;
        }
        return false;
    }

    //
    // cycle through the wind stations by swiping
    //
    function onDownKey() {
        if ((windData != null) && (windData.size() > 0)) {
            iWindData = (iWindData + 1) % windData.size();
            Ui.requestUpdate();
        }
    }

    //
    // used to cycle through wind stations
    //
    function onUpKey() {
        if ((windData != null) && (windData.size() > 0)) {
            iWindData--;
            if (iWindData < 0) { iWindData = windData.size() - 1; }
            Ui.requestUpdate();
        }
    }

    //
    // Make a web request to get the wind data from the internet
    //
    function requestWindData() {
        System.println("wind: makeRequest()");
        lastDataRefresh = Time.now();
        var url = "http://b.obhall.com/obs/";
        var headers = {
            "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED,
            "Accept" => "application/json"
        };
        Comm.makeWebRequest(
            url, 
            { },
            {
                :headers => headers,
                :method => Comm.HTTP_REQUEST_METHOD_GET,
                :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive));
        System.println("wind: makeRequest() done");
    }

    //
    // Callback for requestWindData
    //
    // responseCode -- HTTP response code when doing the JSON request
    // data -- the raw data that is received
    //
    function onReceive(responseCode, data) 
    {
        System.println("wind: onReceive(): " + responseCode);

        var predictions = null;

        if (responseCode == 200) 
        {
            windData = data;
            System.println(windData);
        }

        Ui.requestUpdate();
    }

    function drawLine(dc, x0, y0, x1, y1)
    {
        dc.drawLine(x0 + screenBiasX, y0 + screenBiasY, x1 + screenBiasX, y1 + screenBiasY);
    }

    function drawText(dc, x, y, font, text, justification)
    {
        dc.drawText(x + screenBiasX, y + screenBiasY, font, text, justification);
    }

    //
    // Update the view
    //
    function onUpdate(dc) {
        CommonView.onUpdate(dc);
        // see how long it has been since our last update.  If it has been a while then do the update.
        if (Time.now().subtract(lastDataRefresh).value() > 600)
        {
            System.println("wind data refresh");
            requestWindData();
        }

        var bgcolor = Graphics.COLOR_BLACK;
        var fgcolor = Graphics.COLOR_WHITE;

        dc.setColor(bgcolor, bgcolor);
        dc.clear();
        dc.setColor(fgcolor, Graphics.COLOR_TRANSPARENT);

        var y = 0;
        var center = screenWidth / 2;
        var cellHeight = 0;

        if ((windData != null) && (windData.size() > 0)) {
            // The rendering is tweaked to get 3 wind stations onto the 
            // screen at once.  
            for (var i = iWindData; i < windData.size() && y < screenHeight - cellHeight; i++)
            {
                // this just tightens up things a tad
                y--;

                drawLine(dc, 0, y-1, screenWidth, y-1);
                // what we'll show
                var wind = windData[i];
                var speed = "---";
                var dir = "---";
                var windtime = "---";
                var stationName = "---";

                // save process the parameters (don't trust the JSON)
                if (wind != null) {
                    try {
                        stationName = wind["station_name"];
                        speed = wind["wind_speed"];
                        if (speed != null) { speed = speed.format("%.1f"); } else { speed = "---"; }
                        dir = wind["wind_direction"];
                        if (dir == null) { dir = "---"; }
                        windtime = wind["time"].substring(12, 17) + wind["time"].substring(20, 24);
                    } catch (e) {
                        System.println(e);
                    }
                }

                // render it.  

                // station ID on top
                drawText(dc, center, y, TITLE_FONT, stationName, Graphics.TEXT_JUSTIFY_CENTER);
                y += dc.getFontHeight(TITLE_FONT) - 2;

                // show speed, dir, time left to right
                drawText(dc, 45, y, speedFont, speed, Graphics.TEXT_JUSTIFY_RIGHT);

                // time
                drawText(dc, 95, y + 4, WINDTIME_FONT, windtime, Graphics.TEXT_JUSTIFY_LEFT);

                y += dc.getFontHeight(speedFont);

                // direction
                drawText(dc, 48, y - dc.getFontHeight(DIR_FONT) + 3, DIR_FONT, dir, Graphics.TEXT_JUSTIFY_LEFT);
                
                y += 5;

                if (i == iWindData) { cellHeight = y; }
            }
        } else {
            y = 0;
            var font = Graphics.FONT_LARGE;
            y += dc.getFontHeight(font) + 4;
            drawText(dc, center, y, font, "Loading", Graphics.TEXT_JUSTIFY_CENTER);    
            y += dc.getFontHeight(font) + 4;
            drawText(dc, center, y, font, "Wind Stations", Graphics.TEXT_JUSTIFY_CENTER);    
            y += dc.getFontHeight(font) + 4;
        }
    }
}
