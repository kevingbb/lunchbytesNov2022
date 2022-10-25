import { Bar } from "react-chartjs-2";

export const Chart = ({ chartData }) => {
  return (
    <div>
      <Bar
        data={chartData}
        options={{
          scales: {
            y: {
                suggestedMin: 50,
                suggestedMax: 500
            }},
          animation: {
            duration: 0
          },
          plugins: {
            title: {
              display: true,
              text: ""
            }         ,
            legend: {
              display: false
           }
          }
        }}
      />
    </div>
  );
};