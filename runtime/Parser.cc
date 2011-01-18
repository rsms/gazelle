#include <gazelle/Parser.hh>
#include <gazelle/Grammar.hh>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

using namespace gazelle;


static void start_rule_callback(struct gzl_parse_state *state) {
  gzl_parse_stack_frame *frame = DYNARRAY_GET_TOP(state->parse_stack);
  assert(frame->frame_type == gzl_parse_stack_frame::GZL_FRAME_TYPE_RTN);
  gzl_rtn_frame *rtn_frame = &frame->f.rtn_frame;
  ((Parser*)state->user_data)->onStartRule(rtn_frame, rtn_frame->rtn->name);
}

static void end_rule_callback(struct gzl_parse_state *state) {
  gzl_parse_stack_frame *frame = DYNARRAY_GET_TOP(state->parse_stack);
  assert(frame->frame_type == gzl_parse_stack_frame::GZL_FRAME_TYPE_RTN);
  gzl_rtn_frame *rtn_frame = &frame->f.rtn_frame;
  ((Parser*)state->user_data)->onEndRule(rtn_frame, rtn_frame->rtn->name);
}

static void terminal_callback(struct gzl_parse_state *state,
                              struct gzl_terminal *terminal) {
  ((Parser*)state->user_data)->onTerminal(terminal);
}

static void error_unknown_trans_callback(struct gzl_parse_state *state, int ch) {
  ((Parser*)state->user_data)->onUnknownTransitionError(ch);
}

static void error_terminal_callback(struct gzl_parse_state *state,
                                    struct gzl_terminal *terminal) {
  ((Parser*)state->user_data)->onUnexpectedTerminalError(terminal);
}


Parser::Parser(Grammar *grammar) {
  state_ = gzl_alloc_parse_state();
  assert(state_ != NULL);
  state_->user_data = (void*)this;
  // setup bound grammar
  boundGrammar_.terminal_cb = terminal_callback;
  boundGrammar_.start_rule_cb = start_rule_callback;
  boundGrammar_.end_rule_cb = end_rule_callback;
  boundGrammar_.error_char_cb = error_unknown_trans_callback;
  boundGrammar_.error_terminal_cb = error_terminal_callback;
  gzl_init_parse_state(state_, &boundGrammar_);
  setGrammar(grammar);
}


Parser::~Parser() {
  if (state_)
    gzl_free_parse_state(state_);
}
  

void Parser::setGrammar(Grammar *grammar) {
  boundGrammar_.grammar = grammar ? grammar->grammar() : NULL;
}


// Parse a chunk of text. Note that the text need to begin with a valid token
gzl_status Parser::parse(const char *source, size_t len, bool finalize) {
  fprintf(stderr, "Parser::parse: source %p, state_ %p, grammar: %p \n",
          source, state_, boundGrammar_.grammar);
  if (len == 0)
    len = strlen(source);
  gzl_status status = gzl_parse(state_, source, len);
  if (finalize && (status == GZL_STATUS_HARD_EOF || status == GZL_STATUS_OK) ) {
    if (!finalizeParsing())
      status = GZL_STATUS_PREMATURE_EOF_ERROR;
  }
  return status;
}


bool Parser::finalizeParsing() {
  /* Call this function to complete the parse.  This primarily involves
   * calling all the final callbacks.  Will return false if the parse
   * state does not allow EOF here. */
  return gzl_finish_parse(state_);
}


// Convenience method to parse the complete |file|
gzl_status Parser::parseFile(FILE *file) {
  // TODO implementation
  return GZL_STATUS_IO_ERROR;
}