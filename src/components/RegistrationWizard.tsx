import React from 'react';
import { useSelector } from 'react-redux';
import { Container, ProgressBar } from 'react-bootstrap';
import { RootState } from '../store';
import EventSelection from './EventSelection';
import PartnershipForm from './PartnershipForm';
import DivisionLevelSelection from './DivisionLevelSelection';
import ReviewSubmit from './ReviewSubmit';

const RegistrationWizard: React.FC = () => {
  const { currentStep, selectedEvent } = useSelector((state: RootState) => state.registration);

  const getStepComponent = () => {
    switch (currentStep) {
      case 1:
        return <EventSelection />;
      case 2:
        return <PartnershipForm />;
      case 3:
        return <DivisionLevelSelection />;
      case 4:
        return <ReviewSubmit />;
      default:
        return <EventSelection />;
    }
  };

  const getProgress = () => {
    return (currentStep / 4) * 100;
  };

  const getStepLabel = () => {
    switch (currentStep) {
      case 1:
        return 'Select Event';
      case 2:
        return 'Partnership Details';
      case 3:
        return 'Divisions & Levels';
      case 4:
        return 'Review & Submit';
      default:
        return 'Select Event';
    }
  };

  return (
    <Container fluid className="min-vh-100 bg-light">
      <Container className="py-4">
        <div className="text-center mb-4">
          <div className="d-flex align-items-center justify-content-center mb-3">
            {selectedEvent?.logo_url && (
              <img
                src={selectedEvent.logo_url}
                alt={`${selectedEvent.name} logo`}
                style={{ height: '50px', marginRight: '15px' }}
              />
            )}
            <h1 className="mb-0">
              {selectedEvent ? selectedEvent.name : 'Dance Competition Registration'}
            </h1>
          </div>
          <p className="text-muted">Step {currentStep} of 4: {getStepLabel()}</p>
          <ProgressBar now={getProgress()} className="mb-4" style={{ height: '8px' }} />
        </div>
        {getStepComponent()}
      </Container>
    </Container>
  );
};

export default RegistrationWizard;