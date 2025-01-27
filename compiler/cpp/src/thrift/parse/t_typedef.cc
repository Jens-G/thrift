/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
#include <cstdio>

#include "thrift/parse/t_typedef.h"
#include "thrift/parse/t_program.h"

t_type* t_typedef::get_type(std::map<std::string, mapped_type>* generic) {
  return const_cast<t_type*>(const_cast<const t_typedef*>(this)->get_type(generic));
}

const t_type* t_typedef::get_type(std::map<std::string, mapped_type>* generic) const {
  const mapped_type* mapped = get_generic_type(generic);
  if (mapped->get_type() != nullptr) {
    return mapped->get_type();
  }

  if (is_declaration()) {
    return this;  // generic type declaration is fully specialized at usage, not declaration
  }

  printf("Type \"%s\" not defined\n", symbolic_.c_str());
  exit(1);
}

const mapped_type* t_typedef::get_generic_type(std::map<std::string, mapped_type>* generic) const {
  if (type_ != nullptr) {
    return new mapped_type(symbolic_, type_);
  }

  const t_type* type = get_program()->scope()->get_type(symbolic_);
  if ((type != nullptr) && (type != this)) {
    return new mapped_type(symbolic_, type);
  }

  if (generic != nullptr) {
    std::map<std::string, mapped_type>::const_iterator iter = generic->find(symbolic_);
    if ((iter != generic->end()) && (iter->second.get_type() != this)) {
      return &iter->second;
    }
  }

  return new mapped_type(symbolic_, is_declaration());
}

