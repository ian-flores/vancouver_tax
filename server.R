library(shiny)
library(tidyverse)
library(here)
library(leaflet)
library(DT)
library(scales)
# Load in datasets
socio <- read_csv(here("data", "socio_demographic_data.csv"))
prop <- read_csv(here("data", "prop_neigh_summary.csv"))
property_indv <- read_csv(here("data", "clean_individual.csv"))

# Refactor ordering of neighbourhood factors so plots ordering is as desired
socio$municipality <- socio$municipality %>% fct_relevel("Vancouver CMA", "Vancouver CSD")
socio$variable <- socio$variable %>% fct_relevel("0-4", "5-9")

# Static filtered datasets for displaying non-changing summary stats
vancouver_income <- socio %>%
    filter(municipality == "Vancouver CMA", 
           variable_category == "avg_income" | variable_category == "median_income")

vancouver_prop <- prop %>%
    filter(NEIGHBOURHOOD_NAME == "Vancouver CMA")

# More readable x-axis labels for barplots
vars_name <- c('Age Group', 'Household Size', 'House Type', 'Immigration Status')
names(vars_name) <- c('age_group', 'household_size', 'house_type', 'num_people')

##### Define helper functions
# Puts thousand separators into numbers
format_num <- function(x){
    return(formatC(as.numeric(x), format="f", big.mark = ",", digits=0))
}

shinyServer(function(input, output) {
    
    # Filter SES data dynamically based on dropdown selections
    socio_filtered <- reactive(socio %>% 
        filter(municipality == input$municipality_input | municipality == 'Vancouver CMA', 
               variable_category == input$social_input))
    
    neighbourhood_income <- reactive(socio %>% 
        filter(municipality == input$municipality_input, 
                variable_category == "avg_income" | variable_category == "median_income"))
    
    prop_filtered <- reactive(prop %>% 
        filter(NEIGHBOURHOOD_NAME == input$municipality_input))    
    
    
    output$income_map <- renderLeaflet({
        van_spatial_income <- readRDS('data/van_spatial_income.RDS')
        
        labels <- sprintf(
            "<strong>Municipality</strong>: %s <br/> 
            <strong>Average Income</strong>: %s <br/>
            <strong>Median Income</strong>: %s",
            van_spatial_income@data$Name, dollar(van_spatial_income@data$avg_income), dollar(van_spatial_income@data$median_income)
        ) %>% lapply(htmltools::HTML)
        
        pal_avg <- colorBin('YlGn', domain = van_spatial_income$avg_income, bins = 5)
        pal_median <- colorBin('YlGn', domain = van_spatial_income$median_income, bins = 5)
        
        leaflet(van_spatial_income) %>%
            addProviderTiles('OpenStreetMap.BlackAndWhite') %>%
            addPolygons(fillColor = ~pal_avg(avg_income),
                        weight = 1,
                        opacity = 1,
                        color = "white",
                        dashArray = "2",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 5, color = "#666", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
                        label = labels,
                        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "15px", direction = "auto"), 
                        group = 'Average Income') %>%
            addLegend(pal = pal_avg, values = ~avg_income, title = 'Average Income per Person', labFormat = labelFormat(prefix = '$', between = ' - $'), 
                      group = 'Average Income', position = 'topright') %>%
            addPolygons(fillColor = ~pal_median(median_income),
                        weight = 1,
                        opacity = 1,
                        color = "white",
                        dashArray = "2",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 5, color = "#666", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
                        label = labels,
                        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "15px", direction = "auto"), 
                        group = 'Median Income') %>%
            addLegend(pal = pal_median, values = ~median_income, title = 'Median Income per Person', labFormat = labelFormat(prefix = '$', between = ' - $'), 
                      group = 'Median Income', position = 'topright') %>%
            addLayersControl(overlayGroups = c('Average Income', 'Median Income'),
                             options = layersControlOptions(collapsed = FALSE, ), position = 'topright') %>%
            hideGroup('Median Income')
    })
    
    output$property_map <- renderLeaflet({
        
        van_spatial_property <- readRDS('data/van_spatial_property.RDS')
        
        labels <- sprintf(
            "<strong>Municipality</strong>: %s <br/> 
            <strong>Average Value</strong>: %s <br/>
            <strong>Median Value</strong>: %s",
            van_spatial_property@data$Name, dollar(van_spatial_property@data$avg_price), dollar(van_spatial_property@data$median_price)
        ) %>% lapply(htmltools::HTML)
        
        pal_avg <- colorBin('YlGn', domain = van_spatial_property$avg_price, bins = 5)
        pal_median <- colorBin('YlGn', domain = van_spatial_property$median_price, bins = 5)
        
        leaflet(van_spatial_property) %>%
            addProviderTiles('OpenStreetMap.BlackAndWhite') %>%
            addPolygons(fillColor = ~pal_avg(avg_price),
                        weight = 1,
                        opacity = 1,
                        color = "white",
                        dashArray = "2",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 5, color = "#666", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
                        label = labels,
                        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "15px", direction = "auto"), 
                        group = 'Average Property Value') %>%
            addLegend(pal = pal_avg, values = ~avg_price, title = 'Average Value per House', labFormat = labelFormat(prefix = '$', between = ' - $'), 
                      group = 'Average Property Value', position = 'topright') %>%
            addPolygons(fillColor = ~pal_median(median_price),
                        weight = 1,
                        opacity = 1,
                        color = "white",
                        dashArray = "2",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 5, color = "#666", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
                        label = labels,
                        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "15px", direction = "auto"), 
                        group = 'Median Property Value') %>%
            addLegend(pal = pal_median, values = ~median_price, title = 'Median Value per House', labFormat = labelFormat(prefix = '$', between = ' - $'), 
                      group = 'Median Property Value', position = 'topright') %>%
            addLayersControl(overlayGroups = c('Average Property Value', 'Median Property Value'),
                             options = layersControlOptions(collapsed = FALSE, ), position = 'topright') %>%
            hideGroup('Median Property Value')
    })
    
    output$gap_map <- renderLeaflet({
        
        van_spatial_gap <- readRDS('data/van_spatial_gap.RDS')
        
        pal_avg <- colorBin('PRGn', domain = van_spatial_gap$avg_gap, bins = 5)
        pal_median <- colorBin('PRGn', domain = van_spatial_gap$median_gap, bins = 5)
        
        labels <- sprintf(
            "<strong>Municipality</strong>: %s <br/> 
            <strong>Average Gap</strong>: %s <br/>
            <strong>Median Gap</strong>: %s",
            van_spatial_gap@data$Name, dollar(van_spatial_gap@data$avg_gap), dollar(van_spatial_gap@data$median_gap)
        ) %>% lapply(htmltools::HTML)
        
        property_map <- leaflet(van_spatial_gap) %>%
            addProviderTiles('OpenStreetMap.BlackAndWhite') %>%
            addPolygons(fillColor = ~pal_avg(avg_gap),
                        weight = 1,
                        opacity = 1,
                        color = "white",
                        dashArray = "2",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 5, color = "#666", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
                        label = labels,
                        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "15px", direction = "auto"), 
                        group = 'Average Gap') %>%
            addLegend(pal = pal_avg, values = ~avg_gap, title = 'Average Gap between Income and Property Value', labFormat = labelFormat(prefix = '$', between = ' - $'), 
                      group = 'Average Gap', position = 'topright') %>%
            addPolygons(fillColor = ~pal_median(median_gap),
                        weight = 1,
                        opacity = 1,
                        color = "white",
                        dashArray = "2",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 5, color = "#666", dashArray = "1", fillOpacity = 0.7, bringToFront = TRUE),
                        label = labels,
                        labelOptions = labelOptions(style = list("font-weight" = "normal", padding = "3px 8px"), textsize = "15px", direction = "auto"), 
                        group = 'Median Gap') %>%
            addLegend(pal = pal_median, values = ~median_gap, title = 'Median Gap between Income and Property Value', labFormat = labelFormat(prefix = '$', between = ' - $'), 
                      group = 'Median Gap', position = 'topright') %>%
            addLayersControl(overlayGroups = c('Average Gap', 'Median Gap'),
                             options = layersControlOptions(collapsed = FALSE, ), position = 'topright') %>%
            hideGroup('Median Gap')
    })
  #### Define display functions  
    
  output$distPlot <- renderPlot({
    
    x    <- faithful[, 2] 
    bins <- seq(min(x), max(x), length.out = input$bins + 1)
    
    hist(x, breaks = bins, col = 'darkgray', border = 'white')
    
  })
  
  # Creates Vancouver and neighbourhood-specific barplot for selected SES variable
  output$neigh_barplot <- renderPlot({
      
      # Special filtering required for immigration status variable only
      if (input$social_input == "num_people"){
          status_labels = c("Non-immigrants", "Immigrants", "Non-permanent residents")
          
          socio_filtered() %>%
              filter(variable %in% status_labels) %>%
              ggplot(aes(x=variable, y=value)) +
              geom_bar(stat="identity") +
              coord_flip() +
              facet_wrap(~municipality, ncol=2, scales = "free_x") +
              xlab(vars_name[[input$social_input]]) +
              ylab("Count") +
              ggtitle(paste("Distribution of", vars_name[[input$social_input]])) +
              theme(plot.title = element_text(hjust = 0.5))  

      } else{
          socio_filtered() %>%
              ggplot(aes(x=variable, y=value)) +
              geom_bar(stat="identity") +
              coord_flip() +
              facet_wrap(~municipality, ncol=2, scales = "free_x") +
              xlab(vars_name[[input$social_input]]) +
              ylab("Count") +
              ggtitle(paste("Distribution of", vars_name[[input$social_input]])) +
              theme(plot.title = element_text(hjust = 0.5))     
      }
  })
 
  output$neigh_income <- renderUI({
      avg <- paste('Avg. Annual Income: $',format_num(neighbourhood_income()$value[1]))
      med <- paste('Median Annual Income: $', format_num(neighbourhood_income()$value[2]))
      HTML(paste(avg, med, sep='<br/>'))
  })
  
  output$neigh_value <- renderUI({
      prop_avg <- paste('Avg. Property Value: $',format_num(prop_filtered()$AVG_PROP_VALUE))
      prop_med <- paste('Median Property Value: $',format_num(prop_filtered()$MEDIAN_PROP_VALUE))
      HTML(paste(prop_avg, prop_med, sep='<br/>'))
  })
  
  output$van_income <- renderUI({
      avg <- paste('Avg. Annual Income: $',format_num(vancouver_income$value[1]))
      med <- paste('Median Annual Income: $', format_num(vancouver_income$value[2]))
      HTML(paste(avg, med, sep='<br/>'))
  })
  
  output$van_value <- renderUI({
      prop_avg <- paste('Avg. Property Value: $',format_num(vancouver_prop$AVG_PROP_VALUE))
      prop_med <- paste('Median Property Value: $',format_num(vancouver_prop$MEDIAN_PROP_VALUE))
      HTML(paste(prop_avg, prop_med, sep='<br/>'))
  })
  
  output$van_gap <- renderUI({
      gap <- paste('<b>','Affordability Gap (Avg.): $',format_num(vancouver_income$value[1] - vancouver_prop$AVG_PROP_VALUE/30),'</b>')
      HTML(paste(gap, sep='<br/>'))
  })
  
  output$neigh_gap <- renderUI({
      gap <- paste('<b>','Affordability Gap (Avg.):$',format_num(neighbourhood_income()$value[1] - prop_filtered()$AVG_PROP_VALUE/30),'</b>')
      HTML(paste(gap, sep='<br/>'))
  })
  
  output$property_table <- DT::renderDT({
      datatable(property_indv, 
                colnames = c('Postal Code', 'Land Value', 'Improvement Value', 'Year Built', 'Taxes Payed', 'Total Value', 'Neighbourhood'),
                filter = 'top', 
                options = list(
                    pageLength = 50,
                    lengthMenu = c(5, 10, 15, 20, 25, 50, 100, 150),
                    initComplete = JS(
                        "function(settings, json) {",
                        "$(this.api().table().header()).css({'background-color': '#696969', 'color': '#fff'});",
                        "}")
                ))
  }, server = TRUE)
  
})
