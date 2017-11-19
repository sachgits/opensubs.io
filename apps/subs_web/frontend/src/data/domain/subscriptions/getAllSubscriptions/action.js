import api from 'data/api'

const GET_ALL_SUBSCRIPTIONS_STARTED = 'GET_ALL_SUBSCRIPTIONS_STARTED'
const GET_ALL_SUBSCRIPTIONS_SUCCESS = 'GET_ALL_SUBSCRIPTIONS_SUCCESS'
const GET_ALL_SUBSCRIPTIONS_FAILURE = 'GET_ALL_SUBSCRIPTIONS_FAILURE'

function handleGetStarted(dispatch) {
  dispatch({ type: GET_ALL_SUBSCRIPTIONS_STARTED })
}

function handleGetSuccess(dispatch, response) {
  const { data, meta } = response.data

  dispatch({ type: GET_ALL_SUBSCRIPTIONS_SUCCESS, data, meta })
}

function handleGetFailure(dispatch, error) {
  dispatch({ type: GET_ALL_SUBSCRIPTIONS_FAILURE, error })
}

const getAllSubscriptions = () =>
  (dispatch) => {
    handleGetStarted(dispatch)

    api.getSubscriptions()
      .then(response => handleGetSuccess(dispatch, response))
      .catch(error => handleGetFailure(dispatch, error))
  }

export default getAllSubscriptions

export {
  GET_ALL_SUBSCRIPTIONS_STARTED,
  GET_ALL_SUBSCRIPTIONS_SUCCESS,
  GET_ALL_SUBSCRIPTIONS_FAILURE,
}