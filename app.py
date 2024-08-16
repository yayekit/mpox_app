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

    # Create a choropleth map
    fig = px.choropleth(country_data, 
                        locations="country", 
                        locationmode="country names",
                        color="cases",
                        hover_name="country",
                        color_continuous_scale="Viridis")

    # Convert the plot to HTML
    plot_html = pio.to_html(fig, full_html=False)

    return render_template('index.html', plot=plot_html)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)