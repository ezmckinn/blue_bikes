
library(shiny)
library(leaflet)
library(ggplot2)
library(sf)
library(dplyr)
library(DT)
library(rgdal)
library(RColorBrewer)
library(ggspatial)

#Set working directory 
setwd("/Volumes/Samsung_T5/BlueBikes_COVID_Project/")

#load data
#Define Map Data
segments <- st_read("/Volumes/Samsung_T5/BlueBikes_COVID_Project/data_for_viz/cambridge_results.geojson") %>% arrange(desc(count))
stations <- st_read("/Volumes/Samsung_T5/BlueBikes_COVID_Project/data_for_viz/stations.geojson")
city <- st_read("/Volumes/Samsung_T5/BlueBikes_COVID_Project/BOUNDARY_CityBoundary.shp.zip")
city <- st_transform(city, "+proj=longlat +datum=WGS84") %>% st_transform(4326) %>% st_cast("MULTILINESTRING") #trasnform from shapefile back into lat/lon #transform city data back into 4326
arr_dep <- read.csv("/Volumes/Samsung_T5/BlueBikes_COVID_Project/data_for_viz/hourly_trip_results.csv")

# Define server logic 
shinyServer(function(input, output) {

  map_data <- segments %>% 
    group_by(start_loc)  %>%
    filter(start_loc == 'MIT Vassar St')
  
  start_pal <- colorBin( 
    palette = "BuGn",
    bins = quantile(map_data$count, probs = seq(0, 1, 0.2)),
    domain = map_data$count) 
  
  end_pal <- colorBin( 
    palette = "RdPu",
    bins = quantile(map_data$count, probs = seq(0, 1, 0.2)),
    domain = map_data$count) 
  
  #Drop Down Menus  
  #user_var <- reactive({
  #  switch(input$user_type,
  #          'All' = map_data$count %>% filter(user_type = 'All'),
  #          'Subscriber' = map_data$count %>% filter(user_type = 'Subscriber'),
  #          'Customer' = map_data$count %>% filter(user_type = 'Customer')
  #         )
  #})
  
  #Set up Palettes for maps
  marker_pal <- colorFactor(c("grey","grey","#63B7CF","grey","grey","grey"), domain = c("Cambridge","Boston","Brookline","Somerville","Everett","Watertown"))

    #Line Graph

    #https://stackoverflow.com/questions/59585109/filtering-data-reactively-to-generate-maps
  
    #Set Base Leaflet Map
    output$mymap <- renderLeaflet({ 
      
        #map_data <- segments %>%
        #  filter(stringr::str_detect(start_loc, as.character(input$start)) | input$start == 'All')
      
        leaflet(map_data) %>% 
          setView(-71.065101, 42.361240, zoom = 12) %>%
          addMapPane("points", zIndex = 430) %>%
          addMapPane("polygons", zIndex = 420) %>%
          addMapPane("borders", zIndex = 410) %>%
          addProviderTiles(providers$CartoDB.Positron) %>%  
          addPolygons(data = city, weight = 3, opacity = 0.5, color = '#63B7CF', fillOpacity = 0, options = pathOptions(pane = "borders")) %>%
          addPolylines(smoothFactor = 0.2, opacity = 0.5, group = 'data', #style polylines 
                     color = ~start_pal(count), weight = 2, stroke = TRUE,
                     options = c(pathOptions(interactive = TRUE, pane = "polygons"),popupOptions(autoPan = TRUE)),
                     popup = paste(map_data$start_loc, "to", map_data$end_loc, "<br>", "Trips:", map_data$count)) %>%
          addCircleMarkers(data = stations, radius = 2, layerId = stations$Name,
                           color = ~marker_pal(District), opacity = .9,
                           popup = paste(stations$Name, "<br>", "Docks:", stations$Total.docks),
                           options = c(popupOptions(autoPan = TRUE),
                                        pathOptions(pane = "points"))) 
    })
    
     #set default segment value for map 
    default <- reactive({if_else(is.null(input$mymap_marker_click), 'MIT Vassar St', input$mymap_marker_click$id)})
    
    #Set up Leaflet Proxy For Map Interaction
      observeEvent(c(input$mymap_marker_click, input$test, input$prop), {
       
       pal <- reactive({
         switch(input$test, 
                "Start" = start_pal,
                "End" = end_pal)
       })
         
       dir <- reactive({
         switch(input$test, 
                "Start" = segments$start_loc,
                "End" = segments$end_loc)
       })
       
       leg <- reactive({
         switch(input$test, 
                "Start" = 'Starting at',
                "End" = 'Ending at')
       })
       
       #replace default value with mymap_marker_click
       
       segments$dir <- dir()
       map_data <- segments %>% 
         filter(stringr::str_detect(dir, default())) %>% 
         group_by(default()) %>% slice_max(order_by = count, prop = (input$prop / 100)) #look for value (determined by default fn), in column $dir
       
       leafletProxy("mymap", data = map_data) %>%
         clearControls() %>% 
         clearGroup('data') %>%
         addPolylines(smoothFactor = 0.2, opacity = 0.5, #style polylines 
                      color = ~pal()(count), weight = 2, stroke = TRUE, group = 'data',
                      options = c(pathOptions(interactive = TRUE, pane = "polygons"),
                                  popupOptions(autoPan = TRUE)),
                      popup = paste(map_data$start_loc, "to", map_data$end_loc, "<br>", "Trips:", map_data$count)) %>%
         addLegend("bottomright", pal = pal(), values = ~map_data$count,
                   title = paste("Trips", leg(), "<br>", default()))

     })
       
     output$hist <- renderPlot({
       
        ggplot(arr_dep %>% filter(arr_dep$loc == default()) %>% gather(type, count, dep_ct:arr_ct), 
        aes(x=hour, y=count, fill=forcats::fct_rev(type))) +
        geom_bar(stat="identity") +
        theme(legend.title = element_blank()) +
        scale_fill_manual(values=c("#66c2a4", "#f768a1"), labels = c("Departures", "Arrivals")) +
        xlab("Trip Count") +
        ylab("Hour") 
       
     })
     
     #Summary Stats
     output$selection <- renderText(default())
     
     #Data Tables
     output$trip_table = DT::renderDataTable({
          segments %>% as_tibble() %>% select(-geometry) %>% rename('Start station' = start_loc, 'End station' = end_loc, 'Trip Total' = count, 'User Type' = user_type,'Start District' = start_dist,'End District'= end_dist)
       })
     
     output$station_table = DT::renderDataTable({
          stations %>% as_tibble() %>% select(-geometry) %>% rename('Docks' = Total.docks)
       })
  })


