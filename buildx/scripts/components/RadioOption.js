// COMMIT-TRACKING: UUID-20240729-101938-B4E1
// Description: Created RadioOption component for yes/no selections
// Author: GitHub Copilot
//
// File location diagram:
// jetc/                               <- Main project folder
// └── buildx/                         <- Build directory
//     └── scripts/                    <- Scripts directory
//         └── components/             <- React components
//             └── RadioOption.js      <- THIS FILE

import React from 'react';

const RadioOption = ({ id, name, value, label, checked, onChange }) => {
  return (
    <div className="radio-option">
      <input
        id={id}
        type="radio"
        name={name}
        value={value}
        checked={checked}
        onChange={onChange}
      />
      <label htmlFor={id}>{label}</label>
    </div>
  );
};

export default RadioOption;
