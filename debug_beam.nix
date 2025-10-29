{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Erlang debugging tools
    erlang
    rebar3
    elixir
    
    # Additional debugging tools
    gdb
    valgrind
    strace
    
    # For BEAM debugging
    pkgs.beam.packages.erlangR28.debugger
    pkgs.beam.packages.erlangR28.observer
  ];
  
  shellHook = ''
    echo "BEAM Debug Environment"
    echo "Available tools:"
    echo "  observer        - GUI process inspector"
    echo "  debugger        - Command-line debugger"
    echo "  iex             - Interactive Elixir"
    echo "  erl -debug      - Erlang debugger"
    echo "  recon           - Runtime introspection"
    echo ""
    echo "For Observer GUI (if X11 available):"
    echo "  erl -s observer start"
    echo ""
    echo "For IEx debugging:"
    echo "  iex -S mix"
    echo "  require IEx; IEx.pry()"
  '';
}
