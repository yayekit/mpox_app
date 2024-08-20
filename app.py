# Structure just to remember:
# /mpox_app
#   ├── Dockerfile
#   ├── requirements.txt
#   ├── app.py
#   └── templates
#       └── index.html

import pandas as pd
from flask import Flask, render_template, jsonify
import plotly.express as px
import plotly.io as pio
import plotly.graph_objs as go
from plotly.subplots import make_subplots

app = Flask(__name__)

# Global variable to store the dataframe
df = None

def load_data():
    global df
    url = "https://catalog.ourworldindata.org/explorers/who/latest/monkeypox/monkeypox.csv"
    df = pd.read_csv(url)
    df['date'] = pd.to_datetime(df['date'])
    print("Columns in the DataFrame:", df.columns.tolist())

@app.route('/')
def index():
    load_data()
    
    country_column = next((col for col in df.columns if 'country' in col.lower() or 'location' in col.lower()), None)
    case_column = next((col for col in df.columns if 'case' in col.lower() and 'total' in col.lower()), None)
    
    if not country_column or not case_column:
        return "Error: Unable to find required columns."
    
    country_data = df.groupby(country_column)[case_column].sum().reset_index()
    top_10_countries = country_data.sort_values(case_column, ascending=False).head(10)

    fig = px.pie(top_10_countries, 
                 values=case_column, 
                 names=country_column,
                 title='Top 10 Countries by Mpox Cases',
                 hover_data=[case_column],
                 labels={case_column:'Number of Cases'})

    fig.update_traces(textposition='inside', textinfo='percent+label')
    fig.update_layout(
        legend_title_text='Countries',
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
    )

    plot_html = pio.to_html(fig, full_html=False)
    return render_template('index.html', plot=plot_html)

@app.route('/get_line_chart/<country>')
def get_line_chart(country):
    country_data = df[df['location'] == country].sort_values('date')
    
    fig = make_subplots(specs=[[{"secondary_y": True}]])
    
    fig.add_trace(
        go.Scatter(x=country_data['date'], y=country_data['new_cases'], name="New Cases"),
        secondary_y=False,
    )

    fig.add_trace(
        go.Scatter(x=country_data['date'], y=country_data['new_deaths'], name="New Deaths"),
        secondary_y=True,
    )

    fig.update_layout(
        title_text=f"New Cases and Deaths Over Time in {country}",
        xaxis_title="Date",
    )

    fig.update_yaxes(title_text="New Cases", secondary_y=False)
    fig.update_yaxes(title_text="New Deaths", secondary_y=True)

    return jsonify({"chart": pio.to_json(fig)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)