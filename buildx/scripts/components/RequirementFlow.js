// COMMIT-TRACKING: UUID-20240729-101938-B4E1
// Description: Created RequirementFlow component to manage build requirement steps
// Author: GitHub Copilot
//
// File location diagram:
// jetc/                               <- Main project folder
// └── buildx/                         <- Build directory
//     └── scripts/                    <- Scripts directory
//         └── components/             <- React components
//             └── RequirementFlow.js  <- THIS FILE

import React, { useState } from 'react';
import SingleRequirement from './SingleRequirement';

const RequirementFlow = ({ requirements, onComplete }) => {
  const [currentStep, setCurrentStep] = useState(0);
  const [answers, setAnswers] = useState({});
  
  const handleAnswer = (requirementId, answer) => {
    setAnswers({ ...answers, [requirementId]: answer });
  };
  
  const goToNextStep = () => {
    if (currentStep < requirements.length - 1) {
      setCurrentStep(currentStep + 1);
    } else {
      onComplete(answers);
    }
  };
  
  const goToPreviousStep = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };
  
  const currentRequirement = requirements[currentStep];
  
  return (
    <div className="requirement-flow">
      <SingleRequirement
        key={currentRequirement.id}
        requirement={currentRequirement}
        answer={answers[currentRequirement.id]}
        onAnswer={(answer) => handleAnswer(currentRequirement.id, answer)}
      />
      
      <div className="navigation-buttons">
        {currentStep > 0 && (
          <button onClick={goToPreviousStep}>Back</button>
        )}
        <button 
          onClick={goToNextStep}
          disabled={answers[currentRequirement.id] === undefined}
        >
          {currentStep < requirements.length - 1 ? 'Next' : 'Start Build'}
        </button>
      </div>
      
      <div className="step-indicator">
        Step {currentStep + 1} of {requirements.length}
      </div>
    </div>
  );
};

export default RequirementFlow;
