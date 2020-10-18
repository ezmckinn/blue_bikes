
library(shiny)
library(leaflet)
library(ggplot2)
library(sf)
library(dplyr)
library(DT)
library(maps)
library(rgdal)
library(RColorBrewer)
library(ggspatial)

# Define UI for application that draws a histogram
shinyUI(
    
    navbarPage(strong("Cambridge Blue Bikes"), id = "nav",
               
    tabPanel("Map",
                   div(class = "outer",
        
           tags$head(
             # Include our custom CSS
             includeCSS("styles.css")
           ),
           
            leafletOutput("mymap", height ="100%", width = "100%"),
          
            absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                         draggable = TRUE, top = 50, left = "auto", right = 25, bottom = "auto",
                         width = "20%", height = "auto",
                       
                       h4(strong("Instructions")),
                       
                       #selectInput("user_type", label = "User Type",
                       #             choices = c("All", "Subscription", "Single Ride"),
                       #            selected = "All"),
                       
                       #selectInput("start", label = "Start Station",
                       #            choices = c("All", "MIT at Mass Ave / Amherst St", segments$start_loc[segments$start_loc != "MIT at Mass Ave / Amherst St"]),
                       #            selected = "MIT at Mass Ave / Amherst St"),
                       
                       p("These data reflect Blue Bike trips made to and from Cambridge, from March to September 2020."),
                       p("Use these controls to change the data displayed."),
                       p("The chart below shows daily trip patterns by station."),
                       
                       selectInput("test", label = "Direction",
                                   choices = c("Start", "End"),
                                   selected = "Start"),
                       
                       numericInput("prop",
                         label = "Top N% of Routes to Display",
                         25,
                         min = 5,
                         max = 100,
                         step = 5
                       )
                       
                       #p(textOutput(h3(strong(paste("selection"))))),
                       
                       #p(strong("Top 3 Origins")),
                          #object calculating top 3
                       
                       #p(strong("Top 3 Destinations")),
                          #object calcuating top 3
                       
                       #textOutput(paste("Arrivals Percentile:","Rank")),
                                  
                          # object calculating percent by arrivals count
                       #textOutput(paste("Departures Percentile:","Rank"))
                       
                       #renderPrint("Number of Docks"),
                       #renderPrint(paste("Top 3 Places People Go","Percentile %%")),
                       #renderPrint(paste("Top 3 Origins People Come From", "Percentile %%"))
                       
                       
                       ),
            
            absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                         draggable = TRUE, top = "auto", left = 15, right = "auto", bottom = 15,
                         width = "50%", height = "200",
                        
                         h4(strong("Arrivals and Departures by Hour")),
                         plotOutput("hist", height = "150")
                      
                         )
                      
                   )
                ),
        
    tabPanel("The Data",
             
             tabsetPanel(
                tabPanel("Routes", DT::dataTableOutput("trip_table")),
                tabPanel("Stations", DT::dataTableOutput("station_table"))
             )
    ),
    
    tabPanel("About",
             
             p(''),
             p("Data for this project were provided by", a("Blue Bikes Boston.", href = "https://www.bluebikes.com/system-data"), "Emmett McKinney visualized the data using PostgreSQL, PostGIS, Leaflet, and R."),
             p("Learn more about Emmett's work through his ", a("portfolio,", href = "bit.ly/ezm_design_0620"), "and find him on ", a("LinkedIn, ", href = "bit.ly/ezm_design_0620"), a("GitHub, ", href = "https://github.com/ezmckinn/"), "or ", a("Twitter", href = "https://twitter.com/EmmettMcKinney"))
      )  
      
    )
  )

 ## END ##

