import React, { useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Container, Row, Col, Card, Button, Alert, Spinner, Badge } from 'react-bootstrap';
import { RootState } from '../store';
import { setCurrentStep, resetForm, setLoading, setError } from '../features/registration/registrationSlice';
import { supabase } from '../utils/supabase';

const ReviewSubmit: React.FC = () => {
  const dispatch = useDispatch();
  const { formData, selectedEvent, eventConfig, isLoading } = useSelector((state: RootState) => state.registration);
  const [submitSuccess, setSubmitSuccess] = useState(false);

  const handleSubmit = async () => {
    if (!formData.partnership || !selectedEvent || !eventConfig) {
      dispatch(setError('Missing required information'));
      return;
    }

    dispatch(setLoading(true));
    try {
      // Create or get dancers
      const leaderData = {
        first_name: formData.partnership?.leader?.first_name || '',
        last_name: formData.partnership?.leader?.last_name || '',
        email: formData.partnership?.leader?.email || '',
        phone: formData.partnership?.leader?.phone,
        date_of_birth: formData.partnership?.leader?.date_of_birth,
        is_professional: formData.partnership?.leader?.is_professional || false,
      };

      const followerData = {
        first_name: formData.partnership?.follower?.first_name || '',
        last_name: formData.partnership?.follower?.last_name || '',
        email: formData.partnership?.follower?.email || '',
        phone: formData.partnership?.follower?.phone,
        date_of_birth: formData.partnership?.follower?.date_of_birth,
        is_professional: formData.partnership?.follower?.is_professional || false,
      };

      const { data: leader, error: leaderError } = await supabase
        .from('dancers')
        .upsert(leaderData, { onConflict: 'email' })
        .select()
        .single();

      if (leaderError) throw leaderError;

      const { data: follower, error: followerError } = await supabase
        .from('dancers')
        .upsert(followerData, { onConflict: 'email' })
        .select()
        .single();

      if (followerError) throw followerError;

      // Create partnership
      const { data: partnership, error: partnershipError } = await supabase
        .from('partnerships')
        .insert({
          leader_id: leader.id,
          follower_id: follower.id,
          event_id: selectedEvent.id,
        })
        .select()
        .single();

      if (partnershipError) throw partnershipError;

      // Create registrations for each selected combination
      const registrations = [];
      for (const ageDivisionId of formData.selected_age_divisions || []) {
        for (const skillLevelId of formData.selected_skill_levels || []) {
          const selectedDanceIds = Object.keys(formData.selected_dances || {}).filter(
            danceId => formData.selected_dances![danceId]
          );

          const { data: registration, error: regError } = await supabase
            .from('registrations')
            .insert({
              partnership_id: partnership.id,
              age_division_id: ageDivisionId,
              skill_level_id: skillLevelId,
              selected_dances: selectedDanceIds,
              status: 'pending',
            })
            .select()
            .single();

          if (regError) throw regError;
          registrations.push(registration);
        }
      }

      setSubmitSuccess(true);
      dispatch(resetForm());
    } catch (err) {
      dispatch(setError(err instanceof Error ? err.message : 'Failed to submit registration'));
    } finally {
      dispatch(setLoading(false));
    }
  };

  if (submitSuccess) {
    return (
      <Container>
        <Row className="justify-content-center">
          <Col md={6}>
            <Alert variant="success" className="text-center">
              <h4>Registration Submitted Successfully!</h4>
              <p>You will receive a confirmation email shortly.</p>
              <Button variant="primary" onClick={() => window.location.reload()}>
                Register Another Partnership
              </Button>
            </Alert>
          </Col>
        </Row>
      </Container>
    );
  }

  const getDivisionName = (id: string) => {
    return eventConfig?.age_divisions.find(d => d.id === id)?.name || id;
  };

  const getLevelName = (id: string) => {
    return eventConfig?.skill_levels.find(l => l.id === id)?.name || id;
  };

  const getSelectedDancesGrouped = () => {
    if (!eventConfig || !formData.selected_dances) {
      return {};
    }

    const groupedDances: { [categoryName: string]: string[] } = {};

    for (const [danceId, selected] of Object.entries(formData.selected_dances)) {
      if (selected) {
        // Parse danceId to get category and dance name
        // Format: categoryId|danceName
        const firstPipeIndex = danceId.indexOf('|');
        if (firstPipeIndex !== -1) {
          const categoryId = danceId.substring(0, firstPipeIndex);
          const dancePart = danceId.substring(firstPipeIndex + 1);

          // Find the category
          const category = eventConfig.dance_categories.find(c => c.id === categoryId);

          if (category) {
            // Find the actual dance name by exact match
            const actualDanceName = category.dances.find(d => d === dancePart);

            if (actualDanceName) {
              if (!groupedDances[category.name]) {
                groupedDances[category.name] = [];
              }
              groupedDances[category.name].push(actualDanceName);
            }
          }
        }
      }
    }

    return groupedDances;
  };

  return (
    <Container>
      <Row className="justify-content-center">
        <Col md={8}>
          <h2 className="text-center mb-4">Review Your Registration</h2>

          <Card className="mb-4">
            <Card.Header>
              <h5>Event: {selectedEvent?.name}</h5>
            </Card.Header>
          </Card>

          <Row>
            <Col md={6}>
              <Card className="mb-4">
                <Card.Header>
                  <h5>Leader</h5>
                </Card.Header>
                <Card.Body>
                  <p><strong>Name:</strong> {formData.partnership?.leader?.first_name || ''} {formData.partnership?.leader?.last_name || ''}</p>
                  <p><strong>Email:</strong> {formData.partnership?.leader?.email || ''}</p>
                  <p><strong>Professional:</strong> {formData.partnership?.leader?.is_professional ? 'Yes' : 'No'}</p>
                </Card.Body>
              </Card>
            </Col>

            <Col md={6}>
              <Card className="mb-4">
                <Card.Header>
                  <h5>Follower</h5>
                </Card.Header>
                <Card.Body>
                  <p><strong>Name:</strong> {formData.partnership?.follower?.first_name || ''} {formData.partnership?.follower?.last_name || ''}</p>
                  <p><strong>Email:</strong> {formData.partnership?.follower?.email || ''}</p>
                  <p><strong>Professional:</strong> {formData.partnership?.follower?.is_professional ? 'Yes' : 'No'}</p>
                </Card.Body>
              </Card>
            </Col>
          </Row>

          <Card className="mb-4 shadow-sm">
            <Card.Header className="bg-light">
              <h5 className="mb-0">Competition Selections</h5>
            </Card.Header>
            <Card.Body className="p-3">
              <Row className="g-3">
                <Col md={4}>
                  <div className="mb-2">
                    <small className="text-muted fw-bold">AGE DIVISIONS</small>
                  </div>
                  <div className="d-flex flex-wrap gap-1">
                    {formData.selected_age_divisions?.map(id => (
                      <Badge key={id} bg="secondary">
                        {getDivisionName(id)}
                      </Badge>
                    ))}
                  </div>
                </Col>
                <Col md={4}>
                  <div className="mb-2">
                    <small className="text-muted fw-bold">SKILL LEVELS</small>
                  </div>
                  <div className="d-flex flex-wrap gap-1">
                    {formData.selected_skill_levels?.map(id => (
                      <Badge key={id} bg="secondary">
                        {getLevelName(id)}
                      </Badge>
                    ))}
                  </div>
                </Col>
                <Col md={4}>
                  <div className="mb-2">
                    <small className="text-muted fw-bold">SELECTED DANCES</small>
                  </div>
                  {(() => {
                    const groupedDances = getSelectedDancesGrouped();
                    const categories = Object.keys(groupedDances);

                    if (categories.length === 0) {
                      return <small className="text-muted">No dances selected</small>;
                    }

                    return (
                      <div className="d-flex flex-column gap-2">
                        {categories.map((categoryName) => (
                          <div key={categoryName}>
                            <small className="text-muted fw-bold">{categoryName}:</small>
                            <div className="d-flex flex-wrap gap-1 mt-1">
                              {groupedDances[categoryName].map((dance, index) => (
                                <Badge key={`${categoryName}-${index}`} bg="secondary">
                                  {dance}
                                </Badge>
                              ))}
                            </div>
                          </div>
                        ))}
                      </div>
                    );
                  })()}
                </Col>
              </Row>
            </Card.Body>
          </Card>

          <Row className="justify-content-center mt-4">
            <Col md={6} className="d-flex justify-content-between">
              <Button variant="secondary" onClick={() => dispatch(setCurrentStep(3))}>
                Back
              </Button>
              <Button
                variant="success"
                onClick={handleSubmit}
                disabled={isLoading}
              >
                {isLoading ? (
                  <>
                    <Spinner as="span" animation="border" size="sm" role="status" />
                    Submitting...
                  </>
                ) : (
                  'Submit Registration'
                )}
              </Button>
            </Col>
          </Row>
        </Col>
      </Row>
    </Container>
  );
};

export default ReviewSubmit;