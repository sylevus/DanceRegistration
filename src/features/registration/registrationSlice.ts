import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { RegistrationFormData, Event, EventConfiguration } from '../../types';

interface RegistrationState {
  currentStep: number;
  formData: Partial<RegistrationFormData>;
  events: Event[];
  selectedEvent: Event | null;
  eventConfig: EventConfiguration | null;
  isLoading: boolean;
  error: string | null;
}

const initialState: RegistrationState = {
  currentStep: 1,
  formData: {},
  events: [],
  selectedEvent: null,
  eventConfig: null,
  isLoading: false,
  error: null,
};

const registrationSlice = createSlice({
  name: 'registration',
  initialState,
  reducers: {
    setCurrentStep: (state, action: PayloadAction<number>) => {
      state.currentStep = action.payload;
    },
    updateFormData: (state, action: PayloadAction<Partial<RegistrationFormData>>) => {
      state.formData = { ...state.formData, ...action.payload };
    },
    setEvents: (state, action: PayloadAction<Event[]>) => {
      state.events = action.payload;
    },
    setSelectedEvent: (state, action: PayloadAction<Event>) => {
      state.selectedEvent = action.payload;
    },
    setEventConfig: (state, action: PayloadAction<EventConfiguration>) => {
      state.eventConfig = action.payload;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.isLoading = action.payload;
    },
    setError: (state, action: PayloadAction<string | null>) => {
      state.error = action.payload;
    },
    resetForm: (state) => {
      state.currentStep = 1;
      state.formData = {};
      state.selectedEvent = null;
      state.eventConfig = null;
      state.error = null;
    },
  },
});

export const {
  setCurrentStep,
  updateFormData,
  setEvents,
  setSelectedEvent,
  setEventConfig,
  setLoading,
  setError,
  resetForm,
} = registrationSlice.actions;

export default registrationSlice.reducer;