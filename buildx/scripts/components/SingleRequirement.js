// COMMIT-TRACKING: UUID-20240729-101938-B4E1
// Description: Created SingleRequirement component to display one requirement per page
// Author: GitHub Copilot
//
// File location diagram:
// jetc/                               <- Main project folder
// └── buildx/                         <- Build directory
//     └── scripts/                    <- Scripts directory
//         └── components/             <- React components
//             └── SingleRequirement.js<- THIS FILE

import React from 'react';
import RadioOption from './RadioOption';

const SingleRequirement = ({ requirement, answer, onAnswer }) => {
  return (
    <div className="single-requirement">
      <h2>{requirement.title}</h2>
      <div className="requirement-description">
        {requirement.description}
      </div>
      
      <div className="options">
        <RadioOption
          id={`${requirement.id}-yes`}
          name={requirement.id}
          value="yes"
          label="Yes"
          checked={answer === "yes"}
          onChange={() => onAnswer("yes")}
        />
        
        <RadioOption
          id={`${requirement.id}-no`}
          name={requirement.id}
          value="no"
          label="No"
          checked={answer === "no"}
          onChange={() => onAnswer("no")}
        />
        
        {requirement.allowCustomInput && answer === "no" && (
          <div className="custom-input">
            <label htmlFor={`${requirement.id}-input`}>Please specify:</label>
            <input 
              id={`${requirement.id}-input`}
              type="text" 
              onChange={(e) => onAnswer({ answer: "no", customValue: e.target.value })}
            />
          </div>
        )}
      </div>
    </div>
  );
};

export default SingleRequirement;
