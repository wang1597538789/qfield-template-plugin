import QtQuick
import org.qfield

Item {
  signal prepareResult(var details)
  signal fetchResultsEnded()
  
  function fetchResults(string, context, parameters) {
    console.log('Fetching results from Tianditu v2 (Global Search)....');
    if (parameters["apiKey"] === undefined || parameters["apiKey"] === "") {
      console.log("Tianditu API key is missing.");
      fetchResultsEnded();
      return;
    }
    
    let request = new XMLHttpRequest();
    request.onreadystatechange = function() {
      if (request.readyState === XMLHttpRequest.DONE) {
        if (request.status === 200) {
          let response = JSON.parse(request.responseText);
          // The v2 API response for POIs is slightly different, check for `pois` array directly
          if (response && response.pois) {
            for (let poi of response.pois) {
              let lonlat = poi.lonlat.split(',');
              if (lonlat.length === 2) {
                let lon = parseFloat(lonlat[0]);
                let lat = parseFloat(lonlat[1]);

                let details = {
                  "userData": GeometryUtils.point(lon, lat),
                  "displayString": poi.name,
                  "description": poi.address || "",
                  "score": 1,
                  "group": "天地图全局搜索",
                  "groupScore": 1,
                  "actions": [{
                    "id": 1,
                    "name": "Set as destination",
                    "icon": "qrc:/themes/qfield/nodpi/ic_navigation_flag_purple_24dp.svg"
                  }]
                };
                prepareResult(details);
              }
            }
          }
        }
        fetchResultsEnded();
      }
    }

    let searchParams = {
        "keyWord": string,
        "mapBound": "-180,-90,180,90", // Global extent
        "level": 18, // Fixed high level as per example
        "queryType": 1, // 1: Global/Administrative search
        "start": 0,
        "count": 20
    };
    
    let url = "http://api.tianditu.gov.cn/v2/search?type=query&tk=" + parameters["apiKey"] + "&postStr=" + encodeURIComponent(JSON.stringify(searchParams));
    request.open("GET", url);
    request.send();
  }

}