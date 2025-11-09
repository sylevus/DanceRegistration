import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Container, Row, Col, Form, Button, Card } from 'react-bootstrap';
import { RootState } from '../store';
import { updateFormData, setCurrentStep } from '../features/registration/registrationSlice';

const PartnershipForm: React.FC = () => {
  const dispatch = useDispatch();
  const { formData } = useSelector((state: RootState) => state.registration);

  const handleInputChange = (role: 'leader' | 'follower', field: string, value: string | boolean) => {
    const updatedPartnership = {
      ...formData.partnership,
      [role]: {
        ...(formData.partnership?.[role] || {}),
        [field]: value,
      },
    };
    dispatch(updateFormData({ partnership: updatedPartnership }));
  };

  const handleNext = () => {
    // Basic validation
    const partnership = formData.partnership;
    if (!partnership?.leader?.first_name || !partnership?.leader?.last_name ||
        !partnership?.follower?.first_name || !partnership?.follower?.last_name) {
      alert('Please fill in all required fields for both dancers.');
      return;
    }
    dispatch(setCurrentStep(3));
  };

  const renderDancerForm = (role: 'leader' | 'follower', title: string) => {
    const dancer = formData.partnership?.[role] || {
      first_name: '',
      last_name: '',
      email: '',
      phone: '',
      date_of_birth: '',
      is_professional: false,
    };

    return (
      <Col md={6}>
        <Card className="mb-4">
          <Card.Header>
            <h5 className="mb-0">{title}</h5>
          </Card.Header>
          <Card.Body>
            <Form.Group className="mb-3">
              <Form.Label>First Name *</Form.Label>
              <Form.Control
                type="text"
                value={dancer.first_name || ''}
                onChange={(e) => handleInputChange(role, 'first_name', e.target.value)}
                required
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>Last Name *</Form.Label>
              <Form.Control
                type="text"
                value={dancer.last_name || ''}
                onChange={(e) => handleInputChange(role, 'last_name', e.target.value)}
                required
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>Email *</Form.Label>
              <Form.Control
                type="email"
                value={dancer.email || ''}
                onChange={(e) => handleInputChange(role, 'email', e.target.value)}
                required
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>Phone</Form.Label>
              <Form.Control
                type="tel"
                value={dancer.phone || ''}
                onChange={(e) => handleInputChange(role, 'phone', e.target.value)}
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>Date of Birth</Form.Label>
              <Form.Control
                type="date"
                value={dancer.date_of_birth || ''}
                onChange={(e) => handleInputChange(role, 'date_of_birth', e.target.value)}
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Check
                type="checkbox"
                label="Professional Dancer"
                checked={dancer.is_professional || false}
                onChange={(e) => handleInputChange(role, 'is_professional', e.target.checked)}
              />
            </Form.Group>
          </Card.Body>
        </Card>
      </Col>
    );
  };

  return (
    <Container>
      <Row className="justify-content-center">
        <Col md={10}>
          <h2 className="text-center mb-4">Partnership Information</h2>
          <p className="text-center text-muted mb-4">
            Please provide information for both dancers in this partnership
          </p>

          <Form>
            <Row>
              {renderDancerForm('leader', 'Leader')}
              {renderDancerForm('follower', 'Follower')}
            </Row>

            <Row className="justify-content-center mt-4">
              <Col md={6} className="d-flex justify-content-between">
                <Button variant="secondary" onClick={() => dispatch(setCurrentStep(1))}>
                  Back
                </Button>
                <Button variant="primary" onClick={handleNext}>
                  Next: Select Divisions & Levels
                </Button>
              </Col>
            </Row>
          </Form>
        </Col>
      </Row>
    </Container>
  );
};

export default PartnershipForm;