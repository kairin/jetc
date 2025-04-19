import React, { useState } from 'react';
import './App.css';
import RequirementFlow from '../components/RequirementFlow';

function App() {
  const [showRequirements, setShowRequirements] = useState(true);

  const buildRequirements = [
    {
      id: 'docker-installed',
      title: 'Docker Check',
      description: 'Is Docker installed and running?',
      allowCustomInput: false
    },
    {
      id: 'config-ready',
      title: 'Configuration Ready',
      description: 'Have you prepared your configuration file?',
      allowCustomInput: false
    },
    {
      id: 'dependencies',
      title: 'Dependencies',
      description: 'Are all dependencies installed?',
      allowCustomInput: true
    },
    // Add more requirements as needed
  ];

  const handleBuildRequirementsComplete = (answers) => {
    console.log('Build requirement answers:', answers);
    
    const allRequirementsMet = Object.values(answers).every(
      answer => answer === "yes" || (typeof answer === 'object' && answer.customValue)
    );
    
    if (allRequirementsMet) {
      startBuild();
    } else {
      alert("Please address all requirements before building.");
    }
  };

  return (
    <div className="app">
      {showRequirements && (
        <RequirementFlow 
          requirements={buildRequirements}
          onComplete={handleBuildRequirementsComplete}
        />
      )}
      {/* Rest of your application */}
    </div>
  );
}

export default App;