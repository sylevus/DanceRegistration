import React, { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Container, Row, Col, Form, Button, Card, Alert } from 'react-bootstrap';
import { RootState } from '../store';
import { updateFormData, setCurrentStep, setEventConfig } from '../features/registration/registrationSlice';
import { supabase } from '../utils/supabase';

const DivisionLevelSelection: React.FC = () => {
  const dispatch = useDispatch();
  const { selectedEvent, formData, eventConfig } = useSelector((state: RootState) => state.registration);
  const [selectedAgeDivisions, setSelectedAgeDivisions] = useState<string[]>(formData.selected_age_divisions || []);
  const [selectedSkillLevels, setSelectedSkillLevels] = useState<string[]>(formData.selected_skill_levels || []);
  const [selectedDances, setSelectedDances] = useState<{ [key: string]: boolean }>(formData.selected_dances || {});

  useEffect(() => {
    if (selectedEvent && !eventConfig) {
      const fetchEventConfig = async () => {
        try {
          const { data, error } = await supabase
            .from('event_configurations')
            .select('*')
            .eq('event_id', selectedEvent.id)
            .single();

          if (error) throw error;

          dispatch(setEventConfig(data));
        } catch (err) {
          console.error('Failed to load event configuration:', err);
        }
      };

      fetchEventConfig();
    }
  }, [selectedEvent, eventConfig, dispatch]);

  const handleAgeDivisionChange = (divisionId: string, checked: boolean) => {
    let newSelections = [...selectedAgeDivisions];

    if (checked) {
      if (newSelections.length < 2) {
        newSelections.push(divisionId);
      }
    } else {
      newSelections = newSelections.filter(id => id !== divisionId);
    }

    setSelectedAgeDivisions(newSelections);
  };

  const handleSkillLevelChange = (levelId: string, checked: boolean) => {
    let newSelections = [...selectedSkillLevels];

    if (checked) {
      if (newSelections.length < 2) {
        newSelections.push(levelId);
      }
    } else {
      newSelections = newSelections.filter(id => id !== levelId);
    }

    setSelectedSkillLevels(newSelections);
  };

  const handleDanceChange = (danceId: string, checked: boolean) => {
    setSelectedDances(prev => ({
      ...prev,
      [danceId]: checked,
    }));
  };

  const handleNext = () => {
    if (selectedAgeDivisions.length === 0 || selectedSkillLevels.length === 0) {
      alert('Please select at least one age division and one skill level.');
      return;
    }

    dispatch(updateFormData({
      selected_age_divisions: selectedAgeDivisions,
      selected_skill_levels: selectedSkillLevels,
      selected_dances: selectedDances,
    }));
    dispatch(setCurrentStep(4));
  };

  if (!eventConfig) {
    return (
      <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '50vh' }}>
        <div>Loading event configuration...</div>
      </Container>
    );
  }

  return (
    <Container>
      <Row className="justify-content-center">
        <Col md={10}>
          <h2 className="text-center mb-4">Select Divisions, Levels & Dances</h2>
          <Alert variant="info">
            <strong>Rules:</strong> You may select up to 2 adjacent age divisions and up to 2 skill levels.
            When dancing with a pro, the amateur's age division is used. When two amateurs are dancing,
            the leader's age division is typically used.
          </Alert>

          <Row className="g-3">
            <Col md={4}>
              <Card className="h-100 shadow-sm">
                <Card.Header className="bg-primary text-white py-2">
                  <h6 className="mb-1">Age Divisions</h6>
                  <small>Select up to 2</small>
                </Card.Header>
                <Card.Body className="p-3">
                  <div className="d-flex flex-column gap-2">
                    {[...eventConfig.age_divisions]
                      .sort((a, b) => a.display_order - b.display_order)
                      .map((division) => (
                        <Form.Check
                          key={division.id}
                          type="checkbox"
                          id={`age-${division.id}`}
                          label={<small>{division.name}</small>}
                          checked={selectedAgeDivisions.includes(division.id)}
                          onChange={(e) => handleAgeDivisionChange(division.id, e.target.checked)}
                          disabled={!selectedAgeDivisions.includes(division.id) && selectedAgeDivisions.length >= 2}
                          className="mb-1"
                        />
                      ))}
                  </div>
                </Card.Body>
              </Card>
            </Col>

            <Col md={4}>
              <Card className="h-100 shadow-sm">
                <Card.Header className="bg-success text-white py-2">
                  <h6 className="mb-1">Skill Levels</h6>
                  <small>Select up to 2</small>
                </Card.Header>
                <Card.Body className="p-3">
                  <div className="d-flex flex-column gap-2">
                    {[...eventConfig.skill_levels]
                      .sort((a, b) => a.display_order - b.display_order)
                      .map((level) => (
                        <Form.Check
                          key={level.id}
                          type="checkbox"
                          id={`skill-${level.id}`}
                          label={<small>{level.name}</small>}
                          checked={selectedSkillLevels.includes(level.id)}
                          onChange={(e) => handleSkillLevelChange(level.id, e.target.checked)}
                          disabled={!selectedSkillLevels.includes(level.id) && selectedSkillLevels.length >= 2}
                          className="mb-1"
                        />
                      ))}
                  </div>
                </Card.Body>
              </Card>
            </Col>

            <Col md={4}>
              <Card className="h-100 shadow-sm">
                <Card.Header className="bg-info text-white py-2">
                  <h6 className="mb-1">Dance Categories</h6>
                  <small>Select dances</small>
                </Card.Header>
                <Card.Body className="p-3">
                  {eventConfig.dance_categories.map((category) => (
                    <div key={category.id} className="mb-3">
                      <h6 className="text-muted mb-2">{category.name}</h6>
                      <Row className="g-1">
                        {category.dances.map((dance) => {
                          const danceId = `${category.id}|${dance}`;
                          return (
                            <Col xs={6} key={danceId}>
                              <Form.Check
                                type="checkbox"
                                id={`dance-${danceId}`}
                                label={<small>{dance}</small>}
                                checked={selectedDances[danceId] || false}
                                onChange={(e) => handleDanceChange(danceId, e.target.checked)}
                                className="mb-1"
                              />
                            </Col>
                          );
                        })}
                      </Row>
                    </div>
                  ))}
                </Card.Body>
              </Card>
            </Col>
          </Row>

          <Row className="justify-content-center mt-4">
            <Col md={6} className="d-flex justify-content-between">
              <Button variant="secondary" onClick={() => dispatch(setCurrentStep(2))}>
                Back
              </Button>
              <Button variant="primary" onClick={handleNext}>
                Next: Review & Submit
              </Button>
            </Col>
          </Row>
        </Col>
      </Row>
    </Container>
  );
};

export default DivisionLevelSelection;