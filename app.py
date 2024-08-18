# Project structure:
# /mpox_app
#   ├── Dockerfile
#   ├── requirements.txt
#   ├── app.py
#   └── templates
#       └── index.html

# app.py
import pandas as pd
from flask import Flask, render_template
import plotly.express as px
import plotly.io as pio

app = Flask(__name__)

@app.route('/')
def index():
    # Load the data
    url = "https://catalog.ourworldindata.org/explorers/who/latest/monkeypox/monkeypox.csv"
    df = pd.read_csv(url)

    # Group by country and sum the cases
    country_data = df.groupby('country')['cases'].sum().reset_index()
    
    # Sort the data by cases in descending order and get the top 10 countries
    top_10_countries = country_data.sort_values('cases', ascending=False).head(10)

    # Create a pie chart
    fig = px.pie(top_10_countries, 
                 values='cases', 
                 names='country',
                 title='Top 10 Countries by Mpox Cases',
                 hover_data=['cases'],
                 labels={'cases':'Number of Cases'})

    # Adjust the layout for better readability
    fig.update_traces(textposition='inside', textinfo='percent+label')
    fig.update_layout(
        legend_title_text='Countries',
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
    )

    # Convert the plot to HTML
    plot_html = pio.to_html(fig, full_html=False)

    return render_template('index.html', plot=plot_html)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)