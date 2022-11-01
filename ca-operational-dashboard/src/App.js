import { useEffect, useState } from "react";
import { Chart } from "./components/Chart";
import "./styles.css";

export default function App() {
 
  useEffect(() => {
    const fetchScaleMetrics = async () => {
      const ordersResponse = await fetch('https://' + window._env_.REACT_APP_API + '.' + window._env_.CONTAINER_APP_ENV_DNS_SUFFIX + '/orders');
      var jsonResponse = await ordersResponse.json()
      const queueResponse = await fetch('https://' + window._env_.REACT_APP_API + '.' + window._env_.CONTAINER_APP_ENV_DNS_SUFFIX + '/queue');
      const countMessage = await queueResponse.text();
      const data = [{"name": "Orders in Store","count": jsonResponse.count},{"name": "Orders in Queue","count": countMessage.toString().replace(/[^\d.]/g, '')}]; 
      setScaleChartData({
        labels:  data.map((metric) => metric.name),
        datasets: [
          {
            label: "Count",
            data: data.map((metric) => metric.count),
            backgroundColor: ["#ffbb11","#C0C0C0","#50AF95","#f3ba2f","#2a71d0"]
          }
        ]
      });
    };
    
    fetchScaleMetrics()
    setInterval( function() {fetchScaleMetrics();} , 2 * 1000); 
  
  }, []);

  const [chartScaleData, setScaleChartData] = useState({});
  return (
    <div className="App">
        <div className="Chart">
          <h3>Store Operations</h3>          
          <Chart className="Chart" chartData={chartScaleData} />
        </div>
    </div>
    
  );
}