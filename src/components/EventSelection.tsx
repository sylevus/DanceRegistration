import React, { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Container, Row, Col, Card, Button, Alert, Spinner } from 'react-bootstrap';
import { RootState } from '../store';
import { setEvents, setSelectedEvent, setLoading, setError, setCurrentStep } from '../features/registration/registrationSlice';
import { Event } from '../types';
import { supabase } from '../utils/supabase';

const EventSelection: React.FC = () => {
  const dispatch = useDispatch();
  const { events, isLoading, error } = useSelector((state: RootState) => state.registration);

  useEffect(() => {
    const fetchEvents = async () => {
      dispatch(setLoading(true));
      try {
        console.log('Fetching events from Supabase...');

        // First try simple query without joins
        const { data: simpleData, error: simpleError } = await supabase
          .from('events')
          .select('*');

        console.log('Simple events query result:', { simpleData, simpleError });

        // Then try with joins
        const { data, error } = await supabase
          .from('events')
          .select(`
            *,
            organizations (
              name,
              type
            )
          `);

        console.log('Joined events query result:', { data, error });

        console.log('Raw events data:', data);

        // Filter events with future registration deadlines on the client side
        const upcomingEvents = (data || []).filter(event => {
          const deadline = new Date(event.registration_deadline);
          const now = new Date();
          const isUpcoming = deadline >= now;
          console.log(`Event: ${event.name}, Deadline: ${deadline}, Now: ${now}, Is upcoming: ${isUpcoming}`);
          return isUpcoming;
        });

        console.log('Filtered upcoming events:', upcomingEvents);

        dispatch(setEvents(upcomingEvents));
      } catch (err) {
        dispatch(setError(err instanceof Error ? err.message : 'Failed to load events'));
      } finally {
        dispatch(setLoading(false));
      }
    };

    fetchEvents();
  }, [dispatch]);

  const handleEventSelect = (event: Event) => {
    dispatch(setSelectedEvent(event));
    dispatch(setCurrentStep(2));
  };

  if (isLoading) {
    return (
      <Container className="d-flex justify-content-center align-items-center" style={{ minHeight: '50vh' }}>
        <Spinner animation="border" role="status">
          <span className="visually-hidden">Loading events...</span>
        </Spinner>
      </Container>
    );
  }

  if (error) {
    return (
      <Container>
        <Alert variant="danger">
          <Alert.Heading>Error Loading Events</Alert.Heading>
          <p>{error}</p>
        </Alert>
      </Container>
    );
  }

  return (
    <Container>
      <Row className="justify-content-center">
        <Col md={8}>
          <h1 className="text-center mb-4">Select an Event</h1>
          <p className="text-center text-muted mb-4">
            Choose the dance competition you want to register for
          </p>

          {events.length === 0 ? (
            <Alert variant="info" className="text-center">
              No upcoming events available for registration at this time.
            </Alert>
          ) : (
            <Row>
              {events.map((event) => (
                <Col md={6} key={event.id} className="mb-3">
                  <Card className="h-100">
                    <Card.Body className="d-flex flex-column">
                        <div className="d-flex align-items-start mb-3">
                          {event.logo_url && (
                            <img
                              src={event.logo_url}
                              alt={`${event.name} logo`}
                              style={{ height: '50px', marginRight: '15px', flexShrink: 0 }}
                            />
                          )}
                          <div className="flex-grow-1">
                            <Card.Title className="mb-2">{event.name}</Card.Title>
                            <Card.Subtitle className="mb-3 text-muted">
                              {(event as any).organizations?.name} - {(event as any).organizations?.type}
                            </Card.Subtitle>
                          </div>
                        </div>
                        <Card.Text className="flex-grow-1 mb-3">
                          {event.description && <div className="mb-2">{event.description}</div>}
                          <small className="text-muted">
                            <strong>Event Dates:</strong> {new Date(event.start_date).toLocaleDateString()} - {new Date(event.end_date).toLocaleDateString()}
                            <br />
                            <strong>Registration Deadline:</strong> {new Date(event.registration_deadline).toLocaleDateString()}
                          </small>
                        </Card.Text>
                        <Button
                          variant="primary"
                          onClick={() => handleEventSelect(event)}
                          className="mt-auto"
                        >
                          Register for this Event
                        </Button>
                      </Card.Body>
                  </Card>
                </Col>
              ))}
            </Row>
          )}
        </Col>
      </Row>
    </Container>
  );
};

export default EventSelection;