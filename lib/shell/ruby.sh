function cthul_ruby_ensure_bundle {
    local vendor_path=".vendor/bundle"

    if [ ! -d ${vendor_path} ]; then
      bundle install --path ${vendor_path}
    fi

    if [ Gemfile -nt ${vendor_path} ] || [ Gemfile.lock -nt ${vendor_path} ]; then
      bundle
      touch ${vendor_path}
    fi
}

